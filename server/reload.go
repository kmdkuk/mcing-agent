package server

import (
	"context"
	"os"

	"github.com/itzg/rcon-cli/cli"
	"github.com/kmdkuk/mcing-agent/proto"
)

func (s agentService) Reload(ctx context.Context, req *proto.ReloadRequest) (*proto.ReloadResponse, error) {
	if err := s.agent.Reload(ctx, req); err != nil {
		return nil, err
	}
	return &proto.ReloadResponse{}, nil
}

func (a *Agent) Reload(ctx context.Context, req *proto.ReloadRequest) error {
	// TODO: fload env
	cli.Execute("localhost:25575", "minecraft", os.Stdout, "reload")
	return nil
}
