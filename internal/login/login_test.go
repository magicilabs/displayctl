package login

import (
	"os"
	"path/filepath"
	"testing"
)

func TestByBrewIgnoresDeadAgent(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	agents := filepath.Join(home, "Library", "LaunchAgents")
	if err := os.MkdirAll(agents, 0o755); err != nil {
		t.Fatal(err)
	}
	write := func(exe string) {
		plist := `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>sh.brew.displayctl</string>
	<key>LimitLoadToSessionType</key>
	<array>
		<string>Aqua</string>
	</array>
	<key>ProgramArguments</key>
	<array>
		<string>` + exe + `</string>
		<string>menu</string>
	</array>
</dict>
</plist>
`
		if err := os.WriteFile(filepath.Join(agents, "sh.brew.displayctl.plist"), []byte(plist), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	if ByBrew() {
		t.Fatal("no agent, want false")
	}
	write(filepath.Join(home, "gone", "displayctl"))
	if ByBrew() {
		t.Fatal("agent points at a missing binary, want false")
	}
	exe := filepath.Join(home, "displayctl")
	if err := os.WriteFile(exe, nil, 0o755); err != nil {
		t.Fatal(err)
	}
	write(exe)
	if !ByBrew() {
		t.Fatal("agent points at a real binary, want true")
	}
}
