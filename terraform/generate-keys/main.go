package main

import (
	"bufio"
	"crypto"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"strings"
	"os"

	"github.com/pkg/errors"
	jose "gopkg.in/square/go-jose.v2"
)

// copied from kubernetes/kubernetes#78502
func keyIDFromPublicKey(publicKey interface{}) (string, error) {
	publicKeyDERBytes, err := x509.MarshalPKIXPublicKey(publicKey)
	if err != nil {
		return "", fmt.Errorf("failed to serialize public key to DER format: %v", err)
	}

	hasher := crypto.SHA256.New()
	hasher.Write(publicKeyDERBytes)
	publicKeyDERHash := hasher.Sum(nil)

	keyID := base64.RawURLEncoding.EncodeToString(publicKeyDERHash)

	return keyID, nil
}

func readKey(content string) (string, error) {
	block, _ := pem.Decode([]byte(content))
	if block == nil {
		return "", errors.Errorf("Error decoding PEM file")
	}

	pubKey, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return "", errors.Wrapf(err, "Error parsing key content")
	}
	switch pubKey.(type) {
	case *rsa.PublicKey:
	default:
		return "", errors.New("Public key was not RSA")
	}

	var alg jose.SignatureAlgorithm
	switch pubKey.(type) {
	case *rsa.PublicKey:
		alg = jose.RS256
	default:
		return "", fmt.Errorf("invalid public key type %T, must be *rsa.PrivateKey", pubKey)
	}

	kid, err := keyIDFromPublicKey(pubKey)
	if err != nil {
		return "", err
	}

	key := jose.JSONWebKey{
		Key:       pubKey,
		KeyID:     kid,
		Algorithm: string(alg),
		Use:       "sig",	
	}

	keyJson, err := json.Marshal(key)
	if err != nil {
		return "", err;
	}
	fmt.Println(string(keyJson));
	return "", nil
}

type Input struct {
	PublicKey string `json:"public_key"`
}

func main() {
	// Parse input from stdin
	scanner := bufio.NewScanner(os.Stdin)
	var input []string
	for scanner.Scan() {
		input = append(input, scanner.Text())
	}
	allInput := strings.Join(input[:], "\n")
	var parsedInput Input
	err := json.Unmarshal([]byte(allInput), &parsedInput)
	if err != nil {
		panic(err)
	}

	output, err := readKey(parsedInput.PublicKey)
	if err != nil {
		os.Stderr.WriteString(string(output))
		fmt.Println(err.Error())
	}
}