package telegram

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
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
