package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"os"

	commp "github.com/filecoin-project/go-commp-utils/v2"
	"github.com/filecoin-project/go-state-types/abi"

	_ "github.com/filecoin-project/lotus/build"
)

const proofType = abi.RegisteredSealProof_StackedDrg2KiBV1_1

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	outPath := os.Getenv("PIECE_FILE")
	if outPath == "" {
		outPath = "/tmp/localnet-piece"
	}

	const sectorSize = abi.SectorSize(2048)
	paddedSize := abi.PaddedPieceSize(sectorSize)
	unpaddedSize := paddedSize.Unpadded()

	pieceData := make([]byte, unpaddedSize)
	if _, err := io.ReadFull(rand.Reader, pieceData); err != nil {
		return fmt.Errorf("rand read: %w", err)
	}

	pieceCID, err := commp.GeneratePieceCIDFromFile(proofType, bytes.NewReader(pieceData), unpaddedSize)
	if err != nil {
		return fmt.Errorf("GeneratePieceCIDFromFile: %w", err)
	}

	if err := os.WriteFile(outPath, pieceData, 0600); err != nil {
		return fmt.Errorf("write piece file: %w", err)
	}

	// CommP CIDv1 bytes: 01 81 e2 03 92 20 20 <32-byte-digest>
	//   01       CIDv1
	//   81 e2 03 LEB128(0xf101) fil-commitment-unsealed codec
	//   92 20    LEB128(0x1012) sha2-256-trunc254-padded multihash
	//   20       LEB128(32)     digest length
	cidBytes := pieceCID.Bytes()
	commPHeader := []byte{0x01, 0x81, 0xe2, 0x03, 0x92, 0x20, 0x20}
	if len(cidBytes) != len(commPHeader)+32 {
		return fmt.Errorf("unexpected CommP CID length %d", len(cidBytes))
	}
	if !bytes.Equal(cidBytes[:len(commPHeader)], commPHeader) {
		return fmt.Errorf("unexpected CommP CID header %x", cidBytes[:len(commPHeader)])
	}
	rawDigest := cidBytes[len(commPHeader):]

	fmt.Printf("PIECE_CID=%s\n", pieceCID)
	fmt.Printf("PIECE_FILE=%s\n", outPath)
	fmt.Printf("PIECE_DIGEST=0x%s\n", hex.EncodeToString(rawDigest))

	return nil
}
