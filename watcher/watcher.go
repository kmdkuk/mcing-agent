package watcher

import (
	"context"
	"os"
	"path/filepath"
	"time"

	"github.com/google/go-cmp/cmp"
	"github.com/kmdkuk/mcing-agent/log"
	"github.com/kmdkuk/mcing-agent/rcon"
)

const (
	dataPath        = "/data"
	configPath      = "/mcing-config"
	serverPropsName = "server.properties"
	serverPropsPath = configPath + "/" + serverPropsName
)

func Watch(ctx context.Context, interval time.Duration) error {
	tick := time.NewTicker(interval)
	defer tick.Stop()

	preConfig := map[string][]byte{}

	var err error
	preConfig[serverPropsName], err = os.ReadFile(serverPropsPath)
	if err != nil {
		return err
	}

	for {
		select {
		case <-tick.C:
		case <-ctx.Done():
			log.Debug("quit")
		}

		reload := false
		for k, v := range preConfig {
			path := filepath.Join(configPath, k)
			current, err := os.ReadFile(path)
			if err != nil {
				continue
			}
			if cmp.Equal(string(current), string(v)) {
				continue
			}
			dataPath := filepath.Join(dataPath, k)
			err = os.Remove(dataPath)
			if err != nil {
				continue
			}
			err = os.WriteFile(dataPath, current, 0644)
			if err != nil {
				continue
			}
			preConfig[k] = current
			reload = true
		}

		if reload {
			rcon.Reload()
		}
	}
}
