// Initialize WebSocket connection
const socket = new WebSocket(`ws://${window.location.host}/ws/sensor-data/`);

// Chart configurations
let charts = {
    temperature: null,
    humidity: null,
    gas: null,
    gasGauge: null
};

// Chart color schemes
const chartColors = {
    temperature: {
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)'
    },
    humidity: {
        borderColor: '#10b981',
        backgroundColor: 'rgba(16, 185, 129, 0.1)'
    },
    gas: {
        borderColor: '#f59e0b',
        backgroundColor: 'rgba(245, 158, 11, 0.1)'
    }
};

// Initialize all charts
function initializeCharts() {
    // Temperature Chart
    charts.temperature = new Chart(document.getElementById('tempChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Temperature',
                data: [],
                ...chartColors.temperature,
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                y: { beginAtZero: true }
            }
        }
    });

    // Humidity Chart
    charts.humidity = new Chart(document.getElementById('humChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Humidity',
                data: [],
                ...chartColors.humidity,
                fill: true,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                y: { beginAtZero: true }
            }
        }
    });

    // Gas Gauge Chart
    charts.gasGauge = new Chart(document.getElementById('gasGauge'), {
        type: 'doughnut',
        data: {
            labels: ['Gas Level'],
            datasets: [{
                data: [0, 100],
                backgroundColor: ['#f59e0b', '#e5e7eb'],
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            circumference: 180,
            rotation: 270,
            plugins: {
                legend: { display: false }
            }
        }
    });
}

// Update dashboard with new sensor data
function updateDashboard(data) {
    // Update cards
    document.getElementById('temperature').textContent = `${data.temperature}°C`;
    document.getElementById('humidity').textContent = `${data.humidity}%`;
    document.getElementById('gas').textContent = `${data.gas} ppm`;
    
    // Update status
    const statusElement = document.getElementById('status');
    statusElement.textContent = data.status;
    statusElement.className = `text-3xl font-bold ${getStatusClass(data.status)}`;

    // Update charts
    const now = new Date().toLocaleTimeString();
    updateChart(charts.temperature, now, data.temperature);
    updateChart(charts.humidity, now, data.humidity);
    
    // Update gas gauge
    charts.gasGauge.data.datasets[0].data = [data.gas, 100 - data.gas];
    charts.gasGauge.update();

    // Update last update time
    document.getElementById('lastUpdate').textContent = now;
}

// Helper function to update a single chart
function updateChart(chart, label, value) {
    if (chart.data.labels.length > 10) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    chart.data.labels.push(label);
    chart.data.datasets[0].data.push(value);
    chart.update();
}

// Get appropriate status class for styling
function getStatusClass(status) {
    switch(status.toUpperCase()) {
        case 'LAYAK KONSUMSI':
            return 'status-layak';
        case 'MULAI MEMBUSUK':
            return 'status-warning';
        case 'TIDAK LAYAK':
            return 'status-tidak';
        default:
            return 'text-gray-600';
    }
}

// Load historical data and initialize charts
function loadHistoricalData() {
    fetch('/api/history/')
        .then(response => response.json())
        .then(history => {
            const tableBody = document.getElementById('historyTable');
            tableBody.innerHTML = ''; // Clear existing rows

            history.forEach(row => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>${new Date(row.timestamp).toLocaleString()}</td>
                    <td>${row.temperature}°C</td>
                    <td>${row.humidity}%</td>
                    <td>${row.gas} ppm</td>
                    <td class="${getStatusClass(row.status)}">${row.status}</td>
                `;
                tableBody.appendChild(tr);
            });

            // Initialize charts with historical data
            if (history.length > 0) {
                const labels = history.map(row => new Date(row.timestamp).toLocaleTimeString());
                const tempData = history.map(row => row.temperature);
                const humData = history.map(row => row.humidity);
                const gasData = history.map(row => row.gas);

                // Update all charts with historical data
                charts.temperature.data.labels = labels;
                charts.temperature.data.datasets[0].data = tempData;
                charts.temperature.update();

                charts.humidity.data.labels = labels;
                charts.humidity.data.datasets[0].data = humData;
                charts.humidity.update();

                // Update gas gauge with latest value
                const latestGas = gasData[gasData.length - 1];
                charts.gasGauge.data.datasets[0].data = [latestGas, 100 - latestGas];
                charts.gasGauge.update();
            }
        })
        .catch(error => console.error('Error loading historical data:', error));
}

// WebSocket event handlers
socket.onmessage = function(event) {
    const data = JSON.parse(event.data);
    updateDashboard(data);
};

socket.onclose = function() {
    console.error('WebSocket closed unexpectedly');
    document.querySelector('.realtime-dot').style.background = '#ef4444';
};

// Initialize everything when the page loads
document.addEventListener('DOMContentLoaded', function() {
    initializeCharts();
    loadHistoricalData();
});

// Export functionality
document.getElementById('exportBtn').addEventListener('click', function() {
    window.location.href = '/export/';
});