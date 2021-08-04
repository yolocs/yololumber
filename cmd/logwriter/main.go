package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"cloud.google.com/go/logging"
	"cloud.google.com/go/spanner"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/kelseyhightower/envconfig"

	"go.uber.org/zap"
)

type Config struct {
	InsertFakeLogs bool   `envconfig:"INSERT_FAKE_LOGS"`
	SpannerDB      string `envconfig:"SPANNER_DB"`
}

func main() {
	logger, _ := zap.NewDevelopment()

	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		logger.Fatal("Invalid envs", zap.Error(err))
	}
	ctx := context.Background()

	var client *spanner.Client
	if cfg.SpannerDB != "" {
		var err error
		client, err = spanner.NewClient(ctx, cfg.SpannerDB)
		if err != nil {
			logger.Fatal("Failed to create spanner client", zap.Error(err))
		}
	}

	s := &server{
		logger:         logger,
		insertFakeLogs: cfg.InsertFakeLogs,
		client:         client,
	}
	s.setupRoutes()

	logger.Info("Listening on port 8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		logger.Error("Exited", zap.Error(err))
	}
}

type server struct {
	logger         *zap.Logger
	insertFakeLogs bool
	client         *spanner.Client
	r              *mux.Router
}

type psMessage struct {
	Message struct {
		Attributes map[string]string
		Data       []byte
		ID         string `json:"message_id"`
	}
	Subscription string
}

func (s *server) setupRoutes() {
	s.r = mux.NewRouter()
	s.r.HandleFunc("/logs", s.handleLogMessage)
	s.r.HandleFunc("/admin/cleanup", s.handleCleanup)
	http.Handle("/", s.r)
}

func (s *server) handleLogMessage(w http.ResponseWriter, req *http.Request) {
	msg := psMessage{}
	if err := json.NewDecoder(req.Body).Decode(&msg); err != nil {
		s.logger.Error("Failed to decode request body", zap.Error(err))
		http.Error(w, fmt.Sprintf("Could not decode body: %v", err), http.StatusBadRequest)
		return
	}

	s.logger.Info("Message payload", zap.String("payload", string(msg.Message.Data)))

	if s.insertFakeLogs {
		entry := logging.Entry{InsertID: uuid.NewString(), Timestamp: time.Now()}
		if err := s.insertLog(req.Context(), []byte("fake log payload"), entry); err != nil {
			s.logger.Error("Insert spanner failed", zap.Error(err))
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		return
	}

	var rawLog []byte
	if _, err := base64.StdEncoding.Decode(rawLog, msg.Message.Data); err != nil {
		s.logger.Error("Invalid log format", zap.Error(err))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var entry logging.Entry
	if err := json.Unmarshal(rawLog, &entry); err != nil {
		s.logger.Error("Invalid log format", zap.Error(err))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if s.client == nil {
		w.Write([]byte("WARNING: no spanner is configured; skip"))
		return
	}

	if err := s.insertLog(req.Context(), rawLog, entry); err != nil {
		s.logger.Error("Insert spanner failed", zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func (s *server) insertLog(ctx context.Context, raw []byte, entry logging.Entry) error {
	_, err := s.client.ReadWriteTransaction(ctx, func(ctx context.Context, rwt *spanner.ReadWriteTransaction) error {
		return rwt.BufferWrite([]*spanner.Mutation{spanner.InsertOrUpdate(
			"Logs",
			[]string{"id", "time", "payload"},
			[]interface{}{entry.InsertID, entry.Timestamp, string(raw)},
		)})
	})
	return err
}

func (s *server) handleCleanup(w http.ResponseWriter, req *http.Request) {
	if _, err := s.client.ReadWriteTransaction(req.Context(), func(ctx context.Context, rwt *spanner.ReadWriteTransaction) error {
		_, err := rwt.Update(ctx, spanner.Statement{SQL: `DELETE FROM Logs WHERE true`})
		return err
	}); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}
