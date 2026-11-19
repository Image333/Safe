package routes

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// telegramSendTotal counts Telegram deliveries by channel and outcome.
// channel: alert | audio; status: ok | error | dropped.
var telegramSendTotal = promauto.NewCounterVec(
	prometheus.CounterOpts{
		Name: "telegram_send_total",
		Help: "Telegram deliveries attempted, by channel and status.",
	},
	[]string{"channel", "status"},
)

func recordTelegramSend(channel, status string) {
	telegramSendTotal.WithLabelValues(channel, status).Inc()
}
