package mailer

import (
	"testing"
)

func TestTemplateLoading(t *testing.T) {
	// Test that the template file can be loaded from the embedded filesystem
	tmpl, err := templateFS.ReadFile("templates/user_welcome.tmpl")
	if err != nil {
		t.Fatalf("Failed to read template file: %v", err)
	}
	
	if len(tmpl) == 0 {
		t.Error("Template file is empty")
	}
	
	// Test that the Send method can parse the template
	m := New("localhost", 25, "user", "pass", "sender@example.com")
	
	// Create a mock user with an ID
	type User struct {
		ID int64
	}
	user := User{ID: 123}
	
	// We don't actually want to send an email, so we'll just check if the template parsing works
	// by calling the Send method with a non-existent email address
	err = m.Send("test@example.com", "user_welcome.tmpl", user)
	
	// We expect an error when trying to send the email, but not when parsing the template
	// If the error contains "pattern matches no files", then our fix didn't work
	if err != nil && err.Error() == "template: pattern matches no files: `templates/user_welcome.tmpl`" {
		t.Errorf("Template file not found: %v", err)
	}
}