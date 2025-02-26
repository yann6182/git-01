package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
)

func captureSigint() {
    c := make(chan os.Signal, 1)
    signal.Notify(c, os.Interrupt)

    go func() {
        <-c
        // Reset the TERM and exit
        fmt.Println("\033[0m\033c")
        os.Exit(0)
    }()
}

func termSize() (int, int) {
    cmd := exec.Command("stty", "size")
    cmd.Stdin = os.Stdin
    size, _ := cmd.Output()

    termWidth, _ := strconv.Atoi(strings.TrimSpace(strings.Split(string(size), " ")[1]))
    termHeight, _ := strconv.Atoi(strings.Split(string(size), " ")[0])
    return termWidth, termHeight
}

func main() {
    // Parse options
    flag.Parse()

    // Set output character
    const outputChar = "  "

    // Set colors
    colors := map[string]string{
        "#": "82",      // green
        "@": "223",     // light orange
        "-": "205",     // pink
        "$": "219",     // light pink
        "%": "217",     // peach
        "=": "39",      // blue
        ">": "196",     // red
        "+": "226",     // yellow
        ",": "17",      // deep blue
        ".": "15",      // white
        ";": "99",      // purple
        "&": "214",     // orange
        "'": "0",       // black
        "*": "245",     // grey
    }

    // Import frames from data file
    framesFile, _ := filepath.Abs("assets/frames.json")
    data, _ := ioutil.ReadFile(framesFile)

    var frames [][]string
    json.Unmarshal(data, &frames)

    // Get TTY size
    termWidth, termHeight := termSize()

    // Calculate the width in terms of the output char
    termWidth = termWidth / len(outputChar)

    minRow := 0
    maxRow := len(frames[0])

    minCol := 0
    maxCol := len(frames[0][0])

    if maxRow > termHeight {
        minRow = (maxRow - termHeight) / 2
        maxRow = minRow + termHeight
    }

    if maxCol > termWidth {
        minCol = (maxCol - termWidth) / 2
        maxCol = minCol + termWidth
    }

    // Initialize term
    fmt.Print("\033[H\033[2J\033[?25l")

    // Capture SIGINT
    captureSigint()

    for _, frame := range frames {
        // Print the next frame
        for _, line := range frame[minRow:maxRow] {
            for _, char := range line[minCol:maxCol] {
                fmt.Printf("\033[48;5;%sm%s", colors[string(char)], outputChar)
            }
            fmt.Println("\033[m")
        }
    }
}
