package routes

import (
	"database/sql"
	"fmt"
	"html"
	"log"

	"gpe/telegram"
)

type audioRecipient struct {
	contactID int
	name      string
	chatID    int64
}

// audioJob contains everything needed for delivery: the worker never touches the DB.
type audioJob struct {
	alertID    int
	blobURL    string
	caption    string
	recipients []audioRecipient
}

// deliver downloads the clip once (with retry) then sends it to every recipient.
func (j audioJob) deliver(n *Notifier) {
	var file *telegram.AudioFile
	err := n.retry(func() error {
		var err error
		file, err = n.sender.FetchAudio(j.blobURL)
		return err
	})
	if err != nil {
		recordTelegramSend("audio", "error")
		log.Printf("telegram FetchAudio alerte=%d: %v", j.alertID, err)
		return
	}

	for _, r := range j.recipients {
		err := n.retry(func() error {
			return n.sender.SendAudioFile(r.chatID, file, j.caption)
		})
		if err != nil {
			recordTelegramSend("audio", "error")
			log.Printf("telegram SendAudio contact=%d (%s) alerte=%d: %v", r.contactID, r.name, j.alertID, err)
		} else {
			recordTelegramSend("audio", "ok")
			log.Printf("telegram SendAudio OK contact=%d (%s) alerte=%d", r.contactID, r.name, j.alertID)
		}
	}
}

// buildAudioJob loads the user display name and the Telegram-linked contacts.
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
