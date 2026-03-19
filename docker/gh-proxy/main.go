package main

import (
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/gofiber/fiber/v2"
)

const githubAPI = "https://api.github.com"

var token string

func proxy(c *fiber.Ctx) error {
	// Build target URL: strip "/github" prefix if present, forward the rest
	path := c.Path()
	target := githubAPI + path

	if q := string(c.Request().URI().QueryString()); q != "" {
		target += "?" + q
	}

	req, err := http.NewRequest(c.Method(), target, strings.NewReader(string(c.Body())))
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error()})
	}

	// Forward original headers, then override/inject ours
	c.Request().Header.VisitAll(func(k, v []byte) {
		key := string(k)
		// Skip hop-by-hop headers
		switch strings.ToLower(key) {
		case "host", "connection", "transfer-encoding":
			return
		}
		req.Header.Set(key, string(v))
	})

	req.Header.Set("Authorization", "Bearer "+token)
	// Only set defaults if client didn't provide them (preserves preview media types)
	if req.Header.Get("Accept") == "" {
		req.Header.Set("Accept", "application/vnd.github+json")
	}
	if req.Header.Get("X-GitHub-Api-Version") == "" {
		req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	}
	if req.Header.Get("Content-Type") == "" && len(c.Body()) > 0 {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error()})
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error()})
	}

	// Forward response headers
	for k, vals := range resp.Header {
		switch strings.ToLower(k) {
		case "transfer-encoding", "connection":
			continue
		}
		c.Set(k, vals[0])
	}

	return c.Status(resp.StatusCode).Send(body)
}

func main() {
	token = os.Getenv("GITHUB_TOKEN")
	if token == "" {
		log.Fatal("GITHUB_TOKEN is required")
	}

	app := fiber.New(fiber.Config{
		DisableStartupMessage: true,
	})

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"ok": true})
	})

	// Catch-all: proxy everything else to GitHub API
	app.All("/*", proxy)

	log.Println("gh-proxy listening on :8080")
	log.Fatal(app.Listen(":8080"))
}
