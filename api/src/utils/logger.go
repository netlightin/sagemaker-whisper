package utils

import (
	"log"
	"os"
)

type Logger struct {
	*log.Logger
}

func NewLogger() *Logger {
	return &Logger{
		Logger: log.New(os.Stdout, "[API] ", log.LstdFlags|log.Lshortfile),
	}
}

func (l *Logger) Info(v ...interface{}) {
	l.Println("[INFO]", v)
}

func (l *Logger) Error(v ...interface{}) {
	l.Println("[ERROR]", v)
}

func (l *Logger) Debug(v ...interface{}) {
	l.Println("[DEBUG]", v)
}

func (l *Logger) Fatal(v ...interface{}) {
	l.Fatalln("[FATAL]", v)
}
