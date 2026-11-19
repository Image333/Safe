package routes

import (
	"sync"
	"time"

	"gpe/telegram"
)

const (
	alertNotifyWorkers  = 4
	alertNotifyQueue    = 200
	alertNotifyAttempts = 3

	audioNotifyWorkers  = 4
	audioNotifyQueue    = 100
	audioNotifyAttempts = 3
)

// telegramSender is the subset of the Telegram service the workers need.
// An interface keeps the pool testable without any network call.
type telegramSender interface {
	SendMessage(chatID int64, text string) error
	SendLocation(chatID int64, latitude, longitude float64) error
	FetchAudio(audioURL string) (*telegram.AudioFile, error)
	SendAudioFile(chatID int64, file *telegram.AudioFile, caption string) error
}

// telegramJob is one unit of delivery executed by a worker.
type telegramJob interface {
	deliver(n *Notifier)
}

// Notifier runs a fixed number of workers over a bounded queue, with retry.
// Enqueueing never blocks: a saturated queue drops the job (the caller logs and
// counts it) so an HTTP request is never delayed by Telegram.
type Notifier struct {
	sender     telegramSender
	jobs       chan telegramJob
	attempts   int
	retryDelay time.Duration

	wg     sync.WaitGroup
	mu     sync.RWMutex
	closed bool
}

// NewNotifier starts the workers and returns the queue handle.
func NewNotifier(sender telegramSender, workers, queue, attempts int) *Notifier {
	if workers < 1 {
		workers = 1
	}
	if attempts < 1 {
		attempts = 1
	}
	n := &Notifier{
		sender:     sender,
		jobs:       make(chan telegramJob, queue),
		attempts:   attempts,
		retryDelay: time.Second,
	}
	n.wg.Add(workers)
	for range workers {
		go n.run()
	}
	return n
}

// enqueue queues a job without blocking; false means the queue is full or the
// notifier is closed.
func (n *Notifier) enqueue(job telegramJob) bool {
	n.mu.RLock()
	defer n.mu.RUnlock()
	if n.closed {
		return false
	}
	select {
	case n.jobs <- job:
		return true
	default:
		return false
	}
}

func (n *Notifier) run() {
	defer n.wg.Done()
	for job := range n.jobs {
		job.deliver(n)
	}
}

// Close stops accepting jobs and waits for the running ones to finish.
func (n *Notifier) Close() {
	n.mu.Lock()
	if !n.closed {
		n.closed = true
		close(n.jobs)
	}
	n.mu.Unlock()
	n.wg.Wait()
}

// retry calls fn up to attempts times with a linear backoff.
func (n *Notifier) retry(fn func() error) error {
	var err error
	for attempt := 1; attempt <= n.attempts; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		if attempt < n.attempts {
			time.Sleep(n.retryDelay * time.Duration(attempt))
		}
	}
	return err
}
