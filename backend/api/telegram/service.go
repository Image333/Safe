package telegram

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net"
	"net/http"
	"net/url"
	"os"
	"path"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// MaxAudioBytes caps a downloaded clip (kept in memory before upload to Telegram).
const MaxAudioBytes = 25 << 20

// defaultAPIBase is the Bot API root; overridable in tests via Service.apiBase.
const defaultAPIBase = "https://api.telegram.org"

// Service wraps Telegram Bot API calls.
type Service struct {
	token        string
	botUser      string
	apiBase      string
	httpClient   *http.Client
	audioClient  *http.Client
	audioSources []*url.URL
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
	sources := parseAudioSources(os.Getenv("TELEGRAM_AUDIO_ALLOWED_URLS"))
	if len(sources) == 0 {
		log.Println("Telegram: TELEGRAM_AUDIO_ALLOWED_URLS vide — envoi des clips audio désactivé")
	}
	return &Service{
		token:   token,
		botUser: botUser,
		apiBase: defaultAPIBase,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
		audioClient:  newAudioClient(),
		audioSources: sources,
	}
}

// apiURL builds the Bot API endpoint for one method.
func (s *Service) apiURL(method string) string {
	base := s.apiBase
	if base == "" {
		base = defaultAPIBase
	}
	return fmt.Sprintf("%s/bot%s/%s", base, s.token, method)
}

// scrubError removes the request URL from transport errors. Go wraps failures in
// *url.Error, whose message embeds the full URL including the bot token, so
// neither API responses nor logs may surface the raw error.
func scrubError(op string, err error) error {
	var urlErr *url.Error
	if errors.As(err, &urlErr) {
		return fmt.Errorf("%s: %v", op, urlErr.Err)
	}
	return fmt.Errorf("%s: %v", op, err)
}

// parseAudioSources parses a comma-separated list of allowed URL prefixes,
// e.g. "http://minio-service:9000/audio-bucket/".
func parseAudioSources(raw string) []*url.URL {
	var sources []*url.URL
	for _, item := range strings.Split(raw, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		u, err := url.Parse(item)
		if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
			log.Printf("Telegram: source audio ignorée %q", item)
			continue
		}
		if !strings.HasSuffix(u.Path, "/") {
			u.Path += "/"
		}
		sources = append(sources, u)
	}
	return sources
}

// newAudioClient returns a client dedicated to clip downloads: no redirects
// (they would bypass the allow-list) and no loopback / link-local targets
// (cloud metadata endpoint 169.254.169.254, local services).
func newAudioClient() *http.Client {
	dialer := &net.Dialer{
		Timeout: 10 * time.Second,
		Control: func(network, address string, _ syscall.RawConn) error {
			host, _, err := net.SplitHostPort(address)
			if err != nil {
				return err
			}
			ip := net.ParseIP(host)
			if ip == nil || ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
				ip.IsMulticast() || ip.IsUnspecified() {
				return fmt.Errorf("adresse audio refusée: %s", host)
			}
			return nil
		},
	}
	return &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			DialContext:         dialer.DialContext,
			TLSHandshakeTimeout: 10 * time.Second,
		},
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
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

	resp, err := s.httpClient.Post(s.apiURL("sendMessage"), "application/json", bytes.NewReader(body))
	if err != nil {
		return scrubError("telegram sendMessage", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendMessage %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

// SendLocation sends a native map pin to a Telegram chat.
func (s *Service) SendLocation(chatID int64, latitude, longitude float64) error {
	if s == nil || s.token == "" {
		return fmt.Errorf("telegram non configuré")
	}

	payload := map[string]any{
		"chat_id":   chatID,
		"latitude":  latitude,
		"longitude": longitude,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	resp, err := s.httpClient.Post(s.apiURL("sendLocation"), "application/json", bytes.NewReader(body))
	if err != nil {
		return scrubError("telegram sendLocation", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendLocation %d: %s", resp.StatusCode, string(respBody))
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

	resp, err := s.httpClient.Post(s.apiURL("sendMessage"), "application/json", bytes.NewReader(body))
	if err != nil {
		return scrubError("telegram sendMessage", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
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

	resp, err := s.httpClient.Post(s.apiURL("sendMessage"), "application/json", bytes.NewReader(body))
	if err != nil {
		return scrubError("telegram sendMessage", err)
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendMessage %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

// AudioFile is an alert clip downloaded once, then sent to every contact.
type AudioFile struct {
	Filename string
	Data     []byte
}

// FetchAudio downloads a clip from an allow-listed source (TELEGRAM_AUDIO_ALLOWED_URLS).
// blob_url comes from the client: any other URL is refused to prevent SSRF.
func (s *Service) FetchAudio(audioURL string) (*AudioFile, error) {
	if s == nil || s.token == "" {
		return nil, fmt.Errorf("telegram non configuré")
	}
	u, err := s.checkAudioURL(audioURL)
	if err != nil {
		return nil, err
	}

	resp, err := s.audioClient.Get(u.String())
	if err != nil {
		return nil, scrubError("téléchargement audio", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("téléchargement audio: statut %d", resp.StatusCode)
	}
	if resp.ContentLength > MaxAudioBytes {
		return nil, fmt.Errorf("audio trop volumineux (%d octets)", resp.ContentLength)
	}

	data, err := io.ReadAll(io.LimitReader(resp.Body, MaxAudioBytes+1))
	if err != nil {
		return nil, fmt.Errorf("lecture audio: %w", err)
	}
	if len(data) > MaxAudioBytes {
		return nil, fmt.Errorf("audio trop volumineux (> %d octets)", MaxAudioBytes)
	}

	filename := path.Base(u.Path)
	if filename == "" || filename == "." || filename == "/" {
		filename = "alerte.m4a"
	}
	if !strings.Contains(filename, ".") {
		filename += ".m4a"
	}
	return &AudioFile{Filename: filename, Data: data}, nil
}

// checkAudioURL accepts only http(s) URLs under one of the configured prefixes
// (same scheme, same host:port, path inside the prefix).
func (s *Service) checkAudioURL(raw string) (*url.URL, error) {
	if len(s.audioSources) == 0 {
		return nil, fmt.Errorf("aucune source audio autorisée (TELEGRAM_AUDIO_ALLOWED_URLS)")
	}
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("url audio invalide: %w", err)
	}
	if (u.Scheme != "http" && u.Scheme != "https") || u.User != nil || u.Host == "" {
		return nil, fmt.Errorf("url audio refusée")
	}
	if strings.Contains(u.Path, "..") || strings.Contains(u.RawPath, "..") {
		return nil, fmt.Errorf("url audio refusée")
	}
	for _, src := range s.audioSources {
		if u.Scheme == src.Scheme &&
			strings.EqualFold(u.Host, src.Host) &&
			strings.HasPrefix(u.Path, src.Path) {
			return u, nil
		}
	}
	return nil, fmt.Errorf("url audio hors des sources autorisées")
}

// SendAudioFile sends a downloaded clip to a Telegram chat.
// Uses sendAudio (m4a/mp3) so contacts can play it inline.
func (s *Service) SendAudioFile(chatID int64, file *AudioFile, caption string) error {
	if s == nil || s.token == "" {
		return fmt.Errorf("telegram non configuré")
	}
	if file == nil || len(file.Data) == 0 {
		return fmt.Errorf("audio vide")
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
	part, err := w.CreateFormFile("audio", file.Filename)
	if err != nil {
		return err
	}
	if _, err := part.Write(file.Data); err != nil {
		return fmt.Errorf("copie audio: %w", err)
	}
	if err := w.Close(); err != nil {
		return err
	}

	req, err := http.NewRequest(http.MethodPost, s.apiURL("sendAudio"), &buf)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return scrubError("telegram sendAudio", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
	if resp.StatusCode >= 300 {
		return fmt.Errorf("telegram sendAudio %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}
