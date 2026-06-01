package routes

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

const (
	destDir        = "./data/app/Enregistrement" // <- UN SEUL CHEMIN
	maxUploadBytes = 50 * 1024 * 1024            // 50 MB
)

func uploadRecording() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// si tu as un middleware d'auth, on attend que "user_id" soit présent
		val := c.Locals("user_id")
		userID, _ := val.(int)
		if userID <= 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
		}

		fh, err := c.FormFile("file")
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "file_required"})
		}
		if fh.Size <= 0 || fh.Size > maxUploadBytes {
			return c.Status(fiber.StatusRequestEntityTooLarge).JSON(fiber.Map{"error": "file_too_large", "limit_bytes": maxUploadBytes})
		}

		ext := strings.ToLower(filepath.Ext(fh.Filename))
		allowed := map[string]bool{".wav": true, ".mp3": true, ".m4a": true, ".aac": true, ".3gp": true, ".caf": true}
		if !allowed[ext] {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "unsupported_extension"})
		}

		// S'assurer que le dossier existe
		if err := os.MkdirAll(destDir, 0o750); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mkdir_error"})
		}

		// Nom de fichier robuste : <userId>_<timestamp>_<base_sane>.<ext>
		ts := time.Now().UTC().Format("2006-01-02T150405Z")
		base := strings.TrimSuffix(filepath.Base(fh.Filename), filepath.Ext(fh.Filename))
		safeBase := sanitize(base)
		if safeBase == "" {
			safeBase = "audio"
		}
		finalName := fmt.Sprintf("%d_%s_%s%s", userID, ts, safeBase, ext)
		finalPath := filepath.Join(destDir, finalName)

		src, err := fh.Open()
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "open_error"})
		}
		defer src.Close()

		dst, err := os.Create(finalPath)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "create_error"})
		}
		defer dst.Close()

		if _, err := io.Copy(dst, src); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "write_error"})
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"filename": finalName,
			"path":     finalPath,
			"size":     fh.Size,
		})
	}
}

func sanitize(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '_' || r == '-' {
			b.WriteRune(r)
		} else {
			b.WriteByte('-')
		}
	}
	return strings.Trim(b.String(), "-")
}
