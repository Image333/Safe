package telegram

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func newTestService(sources string) *Service {
	return &Service{
		token:        "test",
		httpClient:   http.DefaultClient,
		audioClient:  newAudioClient(),
		audioSources: parseAudioSources(sources),
	}
}

func TestCheckAudioURL(t *testing.T) {
	s := newTestService("http://minio-service:9000/audio-bucket, http://82.65.130.61:30900/audio-bucket/")

	allowed := []string{
		"http://minio-service:9000/audio-bucket/clip.m4a",
		"http://82.65.130.61:30900/audio-bucket/user/1/clip.m4a",
	}
	for _, u := range allowed {
		if _, err := s.checkAudioURL(u); err != nil {
			t.Errorf("%s devrait être accepté: %v", u, err)
		}
	}

	refused := []string{
		"http://169.254.169.254/latest/meta-data/",
		"http://my-mariadb-service:3306/",
		"http://minio-service:9000/other-bucket/clip.m4a",
		"http://minio-service:9000/audio-bucket-evil/clip.m4a",
		"http://minio-service:9000/audio-bucket/../other-bucket/x",
		"http://minio-service:9000/audio-bucket/%2e%2e/other-bucket/x",
		"https://minio-service:9000/audio-bucket/clip.m4a",
		"http://user:pass@minio-service:9000/audio-bucket/clip.m4a",
		"file:///etc/passwd",
		"",
	}
	for _, u := range refused {
		if _, err := s.checkAudioURL(u); err == nil {
			t.Errorf("%s devrait être refusé", u)
		}
	}
}

func TestCheckAudioURL_NoSourceConfigured(t *testing.T) {
	s := newTestService("")
	if _, err := s.checkAudioURL("http://minio-service:9000/audio-bucket/clip.m4a"); err == nil {
		t.Error("Sans TELEGRAM_AUDIO_ALLOWED_URLS, tout doit être refusé")
	}
}

// TestFetchAudio_LoopbackRefused: even if allow-listed, loopback targets are
// refused by the dedicated dialer.
func TestFetchAudio_LoopbackRefused(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("audio"))
	}))
	defer srv.Close()

	s := newTestService(srv.URL + "/audio-bucket/")
	_, err := s.FetchAudio(srv.URL + "/audio-bucket/clip.m4a")
	if err == nil || !strings.Contains(err.Error(), "refusée") {
		t.Errorf("Erreur 'adresse refusée' attendue, obtenue: %v", err)
	}
}

// TestSendMessage_ErrorHidesToken: a transport failure must not leak the bot
// token, which Go embeds in the request URL of a *url.Error.
func TestSendMessage_ErrorHidesToken(t *testing.T) {
	s := &Service{
		token:      "123456:SECRET_TOKEN",
		apiBase:    "http://127.0.0.1:1",
		httpClient: &http.Client{Timeout: 2 * time.Second},
	}

	err := s.SendMessage(42, "hello")
	if err == nil {
		t.Fatal("une erreur est attendue sur un port fermé")
	}
	if strings.Contains(err.Error(), "SECRET_TOKEN") {
		t.Errorf("le token du bot ne doit pas apparaître dans l'erreur: %v", err)
	}
}

// TestSendMessage_Payload: the Bot API receives the chat id, the text and
// parse_mode=HTML.
func TestSendMessage_Payload(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/bottest-token/sendMessage" {
			t.Errorf("chemin inattendu: %s", r.URL.Path)
		}
		_ = json.NewDecoder(r.Body).Decode(&got)
	}))
	defer srv.Close()

	s := &Service{token: "test-token", apiBase: srv.URL, httpClient: srv.Client()}
	if err := s.SendMessage(42, "<b>urgence</b>"); err != nil {
		t.Fatalf("erreur inattendue: %s", err)
	}
	if got["chat_id"] != float64(42) {
		t.Errorf("chat_id inattendu: %v", got["chat_id"])
	}
	if got["text"] != "<b>urgence</b>" || got["parse_mode"] != "HTML" {
		t.Errorf("payload inattendu: %v", got)
	}
}

// TestSendLocation_Payload: coordinates are sent as JSON numbers.
func TestSendLocation_Payload(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewDecoder(r.Body).Decode(&got)
	}))
	defer srv.Close()

	s := &Service{token: "t", apiBase: srv.URL, httpClient: srv.Client()}
	if err := s.SendLocation(7, 48.85, 2.35); err != nil {
		t.Fatalf("erreur inattendue: %s", err)
	}
	if got["latitude"] != 48.85 || got["longitude"] != 2.35 {
		t.Errorf("coordonnées inattendues: %v", got)
	}
}

// TestSendAudioFile_Payload: the multipart upload carries the clip, its caption
// and HTML mode.
func TestSendAudioFile_Payload(t *testing.T) {
	var (
		chatID, caption, mode string
		content               []byte
	)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			t.Errorf("multipart invalide: %v", err)
			return
		}
		chatID = r.FormValue("chat_id")
		caption = r.FormValue("caption")
		mode = r.FormValue("parse_mode")
		f, _, err := r.FormFile("audio")
		if err == nil {
			defer f.Close()
			content, _ = io.ReadAll(f)
		}
	}))
	defer srv.Close()

	s := &Service{token: "t", apiBase: srv.URL, httpClient: srv.Client()}
	err := s.SendAudioFile(9, &AudioFile{Filename: "clip.m4a", Data: []byte("AUDIO")}, "caption")
	if err != nil {
		t.Fatalf("erreur inattendue: %s", err)
	}
	if chatID != "9" || caption != "caption" || mode != "HTML" {
		t.Errorf("champs inattendus: chat_id=%q caption=%q mode=%q", chatID, caption, mode)
	}
	if string(content) != "AUDIO" {
		t.Errorf("contenu inattendu: %q", content)
	}
}
