package routes

import (
	"database/sql"
	"fmt"
	"html"
	"log"
	"time"

	"gpe/telegram"
)

const (
	audioNotifyWorkers  = 4
	audioNotifyQueue    = 100
	audioNotifyAttempts = 3
)

// audioSender est la partie du service Telegram utilisée pour l'envoi des clips
type audioSender interface {
	FetchAudio(audioURL string) (*telegram.AudioFile, error)
	SendAudioFile(chatID int64, file *telegram.AudioFile, caption string) error
}

type audioRecipient struct {
	contactID int
	name      string
	chatID    int64
}

// audioJob contient tout ce qu'il faut pour l'envoi : le worker n'accède pas à la base
type audioJob struct {
	alertID    int
	blobURL    string
	caption    string
	recipients []audioRecipient
}

// audioNotifier envoie les clips d'alerte aux contacts Telegram via un nombre fixe
// de workers et une file bornée, avec retry
type audioNotifier struct {
	sender     audioSender
	jobs       chan audioJob
	retryDelay time.Duration
}

func newAudioNotifier(sender audioSender) *audioNotifier {
	n := &audioNotifier{
		sender:     sender,
		jobs:       make(chan audioJob, audioNotifyQueue),
		retryDelay: time.Second,
	}
	for i := 0; i < audioNotifyWorkers; i++ {
		go n.run()
	}
	return n
}

// enqueue ajoute un envoi sans bloquer ; retourne false si la file est pleine
func (n *audioNotifier) enqueue(job audioJob) bool {
	select {
	case n.jobs <- job:
		return true
	default:
		return false
	}
}

func (n *audioNotifier) run() {
	for job := range n.jobs {
		n.deliver(job)
	}
}

// deliver télécharge le clip une seule fois puis l'envoie à chaque contact
func (n *audioNotifier) deliver(job audioJob) {
	var file *telegram.AudioFile
	err := n.retry(func() error {
		var err error
		file, err = n.sender.FetchAudio(job.blobURL)
		return err
	})
	if err != nil {
		log.Printf("telegram FetchAudio alerte=%d: %v", job.alertID, err)
		return
	}

	for _, r := range job.recipients {
		err := n.retry(func() error {
			return n.sender.SendAudioFile(r.chatID, file, job.caption)
		})
		if err != nil {
			log.Printf("telegram SendAudio contact=%d (%s) alerte=%d: %v", r.contactID, r.name, job.alertID, err)
		} else {
			log.Printf("telegram SendAudio OK contact=%d (%s) alerte=%d", r.contactID, r.name, job.alertID)
		}
	}
}

func (n *audioNotifier) retry(fn func() error) error {
	var err error
	for attempt := 1; attempt <= audioNotifyAttempts; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		if attempt < audioNotifyAttempts {
			time.Sleep(n.retryDelay * time.Duration(attempt))
		}
	}
	return err
}

// buildAudioJob charge le nom de l'utilisateur et ses contacts liés à Telegram
func buildAudioJob(db *sql.DB, userID, alertID int, blobURL string) (audioJob, error) {
	job := audioJob{alertID: alertID, blobURL: blobURL}

	rows, err := db.Query(`
		SELECT c.contact_id, c.contact_name, c.telegram_chat_id
		FROM contacts c
		INNER JOIN user_contacts uc ON uc.contact_id = c.contact_id
		WHERE uc.user_id = ? AND c.telegram_chat_id IS NOT NULL`, userID)
	if err != nil {
		return job, err
	}
	defer rows.Close()

	for rows.Next() {
		var r audioRecipient
		if err := rows.Scan(&r.contactID, &r.name, &r.chatID); err != nil {
			return job, err
		}
		job.recipients = append(job.recipients, r)
	}
	if err := rows.Err(); err != nil {
		return job, err
	}
	if len(job.recipients) == 0 {
		return job, nil
	}

	// parse_mode HTML : le nom est saisi par l'utilisateur, il doit être échappé
	job.caption = fmt.Sprintf(
		"🎤 <b>Enregistrement d'urgence</b>\n\n%s — alerte #%d",
		html.EscapeString(loadUserDisplayName(db, userID)), alertID,
	)
	return job, nil
}
