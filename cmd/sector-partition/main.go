package main

import (
	"context"
	"fmt"
	"os"
	"strconv"

	"github.com/filecoin-project/go-address"
	"github.com/filecoin-project/go-state-types/abi"

	"github.com/filecoin-project/lotus/api/client"
	"github.com/filecoin-project/lotus/chain/types"
	cliutil "github.com/filecoin-project/lotus/cli/util"
	"github.com/filecoin-project/lotus/node/repo"

	_ "github.com/filecoin-project/lotus/build"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	ctx := context.Background()

	minerAddr, err := address.NewFromString(mustEnv("MINER_ID"))
	if err != nil {
		return fmt.Errorf("parsing MINER_ID: %w", err)
	}

	sectorNum, err := strconv.ParseUint(mustEnv("SECTOR_ID"), 10, 64)
	if err != nil {
		return fmt.Errorf("parsing SECTOR_ID: %w", err)
	}

	lotusPath := os.Getenv("LOTUS_PATH")
	if lotusPath == "" {
		return fmt.Errorf("LOTUS_PATH not set")
	}

	ainfos, err := cliutil.GetAPIInfoFromRepoPath(lotusPath, repo.FullNode)
	if err != nil {
		return fmt.Errorf("GetAPIInfoFromRepoPath: %w", err)
	}
	if len(ainfos) == 0 {
		return fmt.Errorf("no API info found")
	}

	dialAddr, err := ainfos[0].DialArgs("v1")
	if err != nil {
		return fmt.Errorf("DialArgs: %w", err)
	}

	node, closer, err := client.NewFullNodeRPCV1(ctx, dialAddr, ainfos[0].AuthHeader())
	if err != nil {
		return fmt.Errorf("NewFullNodeRPCV1: %w", err)
	}
	defer closer()

	loc, err := node.StateSectorPartition(ctx, minerAddr, abi.SectorNumber(sectorNum), types.EmptyTSK)
	if err != nil {
		return fmt.Errorf("StateSectorPartition: %w", err)
	}

	fmt.Printf("DEADLINE=%d\n", loc.Deadline)
	fmt.Printf("PARTITION=%d\n", loc.Partition)
	return nil
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		fmt.Fprintf(os.Stderr, "env %s is required\n", key)
		os.Exit(1)
	}
	return v
}
