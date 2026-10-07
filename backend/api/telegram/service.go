package telegram

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// Service wraps Telegram Bot API calls.
type Service struct {
	token      string
	botUser    string
	httpClient *http.Client
}

// NewService builds a Telegram service from env vars.
// Returns nil if TELEGRAM_BOT_TOKEN is missing (feature disabled).
func NewService() *Service {
	token := os.Getenv("TELEGRAM_BOT_TOKEN")
	if token == "" {
		log.Println("Telegram: TELEGRAM_BOT_TOKEN manquant — envoi désactivé")
		return nil
	}
	botUser := os.Getenv("TELEGRAM_BOT_USERNAME")
	if botUser == "" {
		botUser = "SafeAlertBot"
	}
	return &Service{
		token:   token,
		botUser: botUser,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

// BotUsername returns the configured bot username (without @).
func (s *Service) BotUsername() string {
	if s == nil {
		return os.Getenv("TELEGRAM_BOT_USERNAME")
	}
	return s.botUser
}

// InviteLink builds a deep-link for /start with the given token.
func (s *Service) InviteLink(inviteToken string) string {
	username := "SafeAlertBot"
	if s != nil && s.botUser != "" {
		username = s.botUser
	} else if env := os.Getenv("TELEGRAM_BOT_USERNAME"); env != "" {
		username = env
	}
	return fmt.Sprintf("https://t.me/%s?start=%s", username, inviteToken)
}

// SendMessage sends a text message to a Telegram chat.
func (s *Service) SendMessage(chatID int64, text string) error {
	if s == nil || s.token == "" {
		return fmt.Errorf("telegram non configuré")
	}

	payload := map[string]any{
		"chat_id":    chatID,
		"text":       text,
		"parse_mode": "HTML",
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", s.token)
	resp, err := s.httpClient.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendMessage %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

// SendContactRequestKeyboard asks the user to share their phone number.
func (s *Service) SendContactRequestKeyboard(chatID int64, text string) error {
	if s == nil || s.token == "" {
		return fmt.Errorf("telegram non configuré")
	}

	payload := map[string]any{
		"chat_id": chatID,
		"text":    text,
		"reply_markup": map[string]any{
			"keyboard": [][]map[string]any{
				{
					{
						"text":            "Partager mon numéro",
						"request_contact": true,
					},
				},
			},
			"resize_keyboard":   true,
			"one_time_keyboard": true,
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", s.token)
	resp, err := s.httpClient.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendMessage %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

// RemoveKeyboard sends a confirmation and removes the custom keyboard.
func (s *Service) RemoveKeyboard(chatID int64, text string) error {
	if s == nil || s.token == "" {
		return fmt.Errorf("telegram non configuré")
	}

	payload := map[string]any{
		"chat_id": chatID,
		"text":    text,
		"reply_markup": map[string]any{
			"remove_keyboard": true,
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", s.token)
	resp, err := s.httpClient.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendMessage %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}
