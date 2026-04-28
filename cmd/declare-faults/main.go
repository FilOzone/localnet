package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strconv"

	"github.com/filecoin-project/go-address"
	"github.com/filecoin-project/go-bitfield"
	"github.com/filecoin-project/go-state-types/abi"
	"github.com/filecoin-project/go-state-types/builtin"
	miner14 "github.com/filecoin-project/go-state-types/builtin/v14/miner"

	lapi "github.com/filecoin-project/lotus/api"
	"github.com/filecoin-project/lotus/api/client"
	"github.com/filecoin-project/lotus/chain/actors"
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

	node, closer, err := connectFullNode(ctx)
	if err != nil {
		return fmt.Errorf("connecting to lotus: %w", err)
	}
	defer closer()

	mi, err := node.StateMinerInfo(ctx, minerAddr, types.EmptyTSK)
	if err != nil {
		return fmt.Errorf("StateMinerInfo: %w", err)
	}

	loc, err := node.StateSectorPartition(ctx, minerAddr, abi.SectorNumber(sectorNum), types.EmptyTSK)
	if err != nil {
		return fmt.Errorf("StateSectorPartition: %w", err)
	}
	fmt.Printf("Sector %d: deadline=%d partition=%d\n", sectorNum, loc.Deadline, loc.Partition)

	sectors := bitfield.New()
	sectors.Set(sectorNum)

	params := &miner14.DeclareFaultsParams{
		Faults: []miner14.FaultDeclaration{{
			Deadline:  loc.Deadline,
			Partition: loc.Partition,
			Sectors:   sectors,
		}},
	}

	_, err = submitMessage(ctx, node, mi.Worker, minerAddr,
		builtin.MethodsMiner.DeclareFaults, params)
	if err != nil {
		return fmt.Errorf("DeclareFaults: %w", err)
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

func connectFullNode(ctx context.Context) (lapi.FullNode, func(), error) {
	lotusPath := os.Getenv("LOTUS_PATH")
	if lotusPath == "" {
		return nil, nil, fmt.Errorf("LOTUS_PATH not set")
	}

	ainfos, err := cliutil.GetAPIInfoFromRepoPath(lotusPath, repo.FullNode)
	if err != nil {
		return nil, nil, fmt.Errorf("GetAPIInfoFromRepoPath: %w", err)
	}
	if len(ainfos) == 0 {
		return nil, nil, fmt.Errorf("no API info found")
	}

	addr, err := ainfos[0].DialArgs("v1")
	if err != nil {
		return nil, nil, fmt.Errorf("DialArgs: %w", err)
	}

	node, closer, err := client.NewFullNodeRPCV1(ctx, addr, ainfos[0].AuthHeader())
	if err != nil {
		return nil, nil, fmt.Errorf("NewFullNodeRPCV1: %w", err)
	}
	return node, closer, nil
}

func submitMessage(
	ctx context.Context,
	node lapi.FullNode,
	from, to address.Address,
	method abi.MethodNum,
	params interface{ MarshalCBOR(io.Writer) error },
) (*lapi.MsgLookup, error) {
	enc, aerr := actors.SerializeParams(params)
	if aerr != nil {
		return nil, fmt.Errorf("SerializeParams: %w", aerr)
	}
	msg, err := node.MpoolPushMessage(ctx, &types.Message{
		To:     to,
		From:   from,
		Method: method,
		Params: enc,
	}, nil)
	if err != nil {
		return nil, fmt.Errorf("MpoolPushMessage: %w", err)
	}
	fmt.Printf("message CID: %s\n", msg.Cid())
	result, err := node.StateWaitMsg(ctx, msg.Cid(), 2, lapi.LookbackNoLimit, true)
	if err != nil {
		return nil, fmt.Errorf("StateWaitMsg: %w", err)
	}
	if !result.Receipt.ExitCode.IsSuccess() {
		return nil, fmt.Errorf("message failed: exit code %s", result.Receipt.ExitCode)
	}
	return result, nil
}
