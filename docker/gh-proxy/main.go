package main

import (
	"bytes"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

const githubAPI = "https://api.github.com"

var (
	token string

	// Custom client with timeout and connection pooling
	httpClient = &http.Client{
		Timeout: 60 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 20,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	// Hop-by-hop headers that must NOT be forwarded upstream
	// content-length is excluded so Go recalculates it from the actual body
	hopHeaders = map[string]bool{
		"host":                true,
		"connection":          true,
		"transfer-encoding":   true,
		"content-length":      true,
		"keep-alive":          true,
		"proxy-authenticate":  true,
		"proxy-authorization": true,
		"te":                  true,
		"trailers":            true,
		"upgrade":             true,
	}
)

func proxy(c *fiber.Ctx) error {
	path := c.Path()
	target := githubAPI + path
	if q := string(c.Request().URI().QueryString()); q != "" {
		target += "?" + q
	}

	// Use bytes.NewReader to preserve binary-safe body
	req, err := http.NewRequest(c.Method(), target, bytes.NewReader(c.Body()))
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error()})
	}

	// Forward original headers, skipping hop-by-hop
	c.Request().Header.VisitAll(func(k, v []byte) {
		if hopHeaders[strings.ToLower(string(k))] {
			return
		}
		req.Header.Set(string(k), string(v))
	})

	// Always inject auth + API version
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	// Accept: GraphQL needs application/json; REST uses GitHub media type
	if req.Header.Get("Accept") == "" {
		if path == "/graphql" {
			req.Header.Set("Accept", "application/json")
		} else {
			req.Header.Set("Accept", "application/vnd.github+json")
		}
	}

	// Default Content-Type for bodies
	if req.Header.Get("Content-Type") == "" && len(c.Body()) > 0 {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error()})
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": err.Error()})
	}

	// Forward response headers — skip hop-by-hop and content-encoding
	// (Fiber already decompressed the body, re-sending the header would corrupt it)
	for k, vals := range resp.Header {
		lk := strings.ToLower(k)
		if hopHeaders[lk] || lk == "content-encoding" {
			continue
		}
		for _, v := range vals {
			c.Append(k, v)
		}
	}

	log.Printf("%s %s → %d (%d bytes)", c.Method(), path, resp.StatusCode, len(body))
	return c.Status(resp.StatusCode).Send(body)
}

func main() {
	token = os.Getenv("GITHUB_TOKEN")
	if token == "" {
		log.Fatal("GITHUB_TOKEN is required")
	}

	app := fiber.New(fiber.Config{
		DisableStartupMessage: true,
		BodyLimit:             32 * 1024 * 1024, // 32 MB — handles large GraphQL responses
	})

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"ok": true})
	})

	// Catch-all: proxy everything to GitHub API
	app.All("/*", proxy)

	log.Println("gh-proxy listening on :8080")
	log.Fatal(app.Listen(":8080"))
}
