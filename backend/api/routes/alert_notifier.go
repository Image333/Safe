package routes

import (
	"database/sql"
	"log"
)

type alertRecipient struct {
	contactID int
	name      string
	chatID    int64
}

// geoPoint is a validated alert location, sent as a native Telegram pin.
type geoPoint struct {
	lat float64
	lng float64
}

// alertJob is one emergency alert fan-out. It is built before the HTTP response
// so the worker never touches the DB.
type alertJob struct {
	alertID    int
	message    string
	pin        *geoPoint
	recipients []alertRecipient
}

// deliver sends the alert text to every linked contact, then the map pin when a
// location was provided. A failed message skips the pin for that contact.
func (j alertJob) deliver(n *Notifier) {
	for _, r := range j.recipients {
		err := n.retry(func() error {
			return n.sender.SendMessage(r.chatID, j.message)
		})
		if err != nil {
			recordTelegramSend("alert", "error")
			log.Printf("telegram SendMessage contact=%d (%s) alerte=%d: %v", r.contactID, r.name, j.alertID, err)
			continue
		}
		recordTelegramSend("alert", "ok")
		if j.pin == nil {
			continue
		}
		if err := n.retry(func() error {
			return n.sender.SendLocation(r.chatID, j.pin.lat, j.pin.lng)
		}); err != nil {
			log.Printf("telegram SendLocation contact=%d (%s) alerte=%d: %v", r.contactID, r.name, j.alertID, err)
		}
	}
}

// buildAlertNotification loads the trusted contacts and returns both the job to
// enqueue and the per-contact status reported to the client. Linked contacts are
// reported as "queued": delivery happens in the background.
func buildAlertNotification(db *sql.DB, userID int, userName string, alertID int, opts alertNotifyOpts) (alertJob, []NotifyResult, error) {
	job := alertJob{alertID: alertID, message: buildAlertTelegramMessage(userName, opts)}
	if validCoords(opts.Latitude, opts.Longitude) {
		job.pin = &geoPoint{lat: *opts.Latitude, lng: *opts.Longitude}
	}

	rows, err := db.Query(`
		SELECT c.contact_id, c.contact_name, c.telegram_chat_id
		FROM contacts c
		INNER JOIN user_contacts uc ON uc.contact_id = c.contact_id
		WHERE uc.user_id = ?`, userID)
	if err != nil {
		return job, nil, err
	}
	defer rows.Close()

	results := []NotifyResult{}
	for rows.Next() {
		var (
			contactID int
			name      string
			chatID    sql.NullInt64
		)
		if err := rows.Scan(&contactID, &name, &chatID); err != nil {
			return job, results, err
		}
		r := NotifyResult{ContactID: contactID, ContactName: name}
		if chatID.Valid {
			r.Status = "queued"
			r.Channel = "telegram"
			job.recipients = append(job.recipients, alertRecipient{
				contactID: contactID,
				name:      name,
				chatID:    chatID.Int64,
			})
		} else {
			r.Status = "not_linked"
		}
		results = append(results, r)
	}
	if err := rows.Err(); err != nil {
		return job, results, err
	}
	return job, results, nil
}

// markUndelivered rewrites queued entries when a job could not be scheduled.
func markUndelivered(results []NotifyResult, reason string) []NotifyResult {
	for i := range results {
		if results[i].Status == "queued" {
			results[i].Status = "error"
			results[i].Error = reason
			recordTelegramSend("alert", "dropped")
		}
	}
	return results
}
