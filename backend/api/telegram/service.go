package telegram

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path"
	"strconv"
	"strings"
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
			Timeout: 60 * time.Second,
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

// SendAudio downloads audio from audioURL and sends it to a Telegram chat.
// Uses sendAudio (m4a/mp3) so contacts can play it inline.
func (s *Service) SendAudio(chatID int64, audioURL, caption string) error {
	if s == nil || s.token == "" {
		return fmt.Errorf("telegram non configuré")
	}
	if audioURL == "" {
		return fmt.Errorf("url audio vide")
	}

	dlResp, err := s.httpClient.Get(audioURL)
	if err != nil {
		return fmt.Errorf("téléchargement audio: %w", err)
	}
	defer dlResp.Body.Close()
	if dlResp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(dlResp.Body, 512))
		return fmt.Errorf("téléchargement audio %d: %s", dlResp.StatusCode, string(body))
	}

	filename := path.Base(audioURL)
	if filename == "" || filename == "." || filename == "/" {
		filename = "alerte.m4a"
	}
	if !strings.Contains(filename, ".") {
		filename += ".m4a"
	}

	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	if err := w.WriteField("chat_id", strconv.FormatInt(chatID, 10)); err != nil {
		return err
	}
	if caption != "" {
		if err := w.WriteField("caption", caption); err != nil {
			return err
		}
		if err := w.WriteField("parse_mode", "HTML"); err != nil {
			return err
		}
	}
	part, err := w.CreateFormFile("audio", filename)
	if err != nil {
		return err
	}
	if _, err := io.Copy(part, dlResp.Body); err != nil {
		return fmt.Errorf("copie audio: %w", err)
	}
	if err := w.Close(); err != nil {
		return err
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendAudio", s.token)
	req, err := http.NewRequest(http.MethodPost, url, &buf)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendAudio %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}
