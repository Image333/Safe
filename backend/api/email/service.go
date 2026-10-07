package email

import (
	"fmt"
	"log"
	"os"
)

// Service is a placeholder for future SMTP invite / alert emails.
// Not wired for sending in the current MVP.
type Service struct {
	host string
	from string
}

// NewService builds an Email service from SMTP_* env vars.
// Returns nil if SMTP_HOST is missing (feature disabled).
func NewService() *Service {
	host := os.Getenv("SMTP_HOST")
	if host == "" {
		log.Println("Email: SMTP_HOST manquant — envoi email désactivé (prévu pour phase suivante)")
		return nil
	}
	from := os.Getenv("SMTP_FROM")
	if from == "" {
		from = "noreply@safe.local"
	}
	return &Service{host: host, from: from}
}

// SendInviteEmail will send a Telegram invite link by email.
// Currently returns not-implemented error — activates in a later phase.
func (s *Service) SendInviteEmail(to, inviteLink, inviterName string) error {
	if s == nil {
		return fmt.Errorf("email non configuré")
	}
	return fmt.Errorf("envoi email d'invitation non encore implémenté")
}
