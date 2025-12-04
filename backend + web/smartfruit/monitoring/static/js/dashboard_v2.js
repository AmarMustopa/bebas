// Sensor threshold values for status indicators (berdasarkan dokumen penelitian)
const thresholds = {
    mq2: { warning: 400, danger: 800 },      // Gas busuk (CH₄, H₂S)
    mq3: { warning: 800, danger: 1500 },     // Alkohol / Etanol
    mq135: { warning: 600, danger: 900 },    // Gas amonia / CO₂
    temperature: { warning: 30, danger: 35 },
    humidity: { warning: 85, danger: 92 }    // Threshold humidity dinaikkan
};

// Blinking interval for TIDAK LAYAK status
let blinkInterval = null;

// Track previous status to avoid repeating sound
let previousStatus = 'LAYAK';

// Function to play voice alert
function playVoiceAlert(message) {
    if ('speechSynthesis' in window) {
        // Cancel any ongoing speech
        window.speechSynthesis.cancel();
        
        const utterance = new SpeechSynthesisUtterance(message);
        utterance.lang = 'id-ID'; // Bahasa Indonesia
        utterance.rate = 1.0;
        utterance.pitch = 1.0;
        utterance.volume = 1.0;
        
        window.speechSynthesis.speak(utterance);
        console.log('Playing voice alert:', message);
    } else {
        console.warn('Speech Synthesis not supported in this browser');
    }
}

// Chart objects
let tempHumChart = null;
let gasChart = null;
let meatQualityChart = null;
let meatQualityData = { layak: 0, total: 0 };
let recentDataBuffer = []; // Buffer untuk menyimpan data realtime terbaru

// Initialize charts
function initializeCharts() {
    // Temperature & Humidity Chart
    const tempHumCanvas = document.getElementById('tempHumChart');
    if (tempHumCanvas) {
        const tempHumCtx = tempHumCanvas.getContext('2d');
        tempHumChart = new Chart(tempHumCtx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [
                    {
                        label: 'Suhu (°C)',
                        borderColor: '#ef4444',
                        data: [],
                        tension: 0.3
                    },
                    {
                        label: 'Kelembapan (%)',
                        borderColor: '#3b82f6',
                        data: [],
                        tension: 0.3
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                    intersect: false,
                    mode: 'index'
                },
                plugins: {
                    legend: {
                        position: 'top'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    // Gas Sensors Chart
    const gasCanvas = document.getElementById('gasChart');
    if (gasCanvas) {
        const gasCtx = gasCanvas.getContext('2d');
        gasChart = new Chart(gasCtx, {
            type: 'bar',
            data: {
                labels: ['MQ2', 'MQ3', 'MQ135'],
                datasets: [{
                    label: 'Konsentrasi Gas (ppm)',
                    backgroundColor: ['#3b82f6', '#8b5cf6', '#10b981'],
                    data: [0, 0, 0]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    // Meat Quality Doughnut Chart
    const meatQualityCanvas = document.getElementById('meatQualityChart');
    if (meatQualityCanvas) {
        const meatQualityCtx = meatQualityCanvas.getContext('2d');
        meatQualityChart = new Chart(meatQualityCtx, {
            type: 'doughnut',
            data: {
                labels: ['Layak', 'Tidak Layak'],
                datasets: [{
                    data: [0, 100],
                    backgroundColor: ['#10b981', '#ef4444'],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '70%',
                plugins: {
                    legend: { 
                        display: true,
                        position: 'bottom'
                    },
                    tooltip: { 
                        enabled: true,
                        callbacks: {
                            label: function(context) {
                                let label = context.label || '';
                                if (label) {
                                    label += ': ';
                                }
                                const total = context.dataset.data[0] + context.dataset.data[1];
                                const percentage = total > 0 ? ((context.parsed / total) * 100).toFixed(1) : 0;
                                label += percentage + '%';
                                return label;
                            }
                        }
                    }
                },
                animation: {
                    animateRotate: true,
                    animateScale: true
                }
            }
        });
    }
}

// Update sensor status and card appearance
function updateSensorStatus(sensorId, value, thresholds) {
    const statusElement = document.getElementById(`${sensorId}-status`);
    const card = document.getElementById(`${sensorId}-card`);
    
    if (!statusElement) return;

    let status = 'Normal';
    let statusClass = 'normal';
    let statusColor = 'status-layak';

    if (value >= thresholds.danger) {
        status = 'Danger';
        statusClass = 'danger';
        statusColor = 'status-tidak';
    } else if (value >= thresholds.warning) {
        status = 'Warning';
        statusClass = 'warning';
        statusColor = 'status-warning';
    }

    statusElement.textContent = status;
    statusElement.className = `text-sm font-medium ${statusColor}`;
    
    if (card) {
        card.className = `status-card ${statusClass}`;
    }
}

// Animate value changes
function animateValue(element, start, end, duration) {
    if (!element) return;
    
    let startTimestamp = null;
    const step = (timestamp) => {
        if (!startTimestamp) startTimestamp = timestamp;
        const progress = Math.min((timestamp - startTimestamp) / duration, 1);
        const value = Math.floor(progress * (end - start) + start);
        element.textContent = value + element.dataset.unit;
        if (progress < 1) {
            window.requestAnimationFrame(step);
        }
    };
    window.requestAnimationFrame(step);
}

// Old modal-based sensor detail functions removed.
// Navigation now uses full-page detail views (e.g. /sensor-detail/mq2/).
// If you need to restore modal behavior, re-implement showSensorDetail() here.

// Update dashboard with new sensor data
function updateDashboard(data) {
    // Update sensor values
    const mq2El = document.getElementById('mq2-value');
    if (mq2El) mq2El.textContent = (Math.round(data.mq2 * 10) / 10) + ' ppm';
    
    const mq3El = document.getElementById('mq3-value');
    if (mq3El) mq3El.textContent = (Math.round(data.mq3 * 10) / 10) + ' ppm';
    
    const mq135El = document.getElementById('mq135-value');
    if (mq135El) mq135El.textContent = (Math.round(data.mq135 * 10) / 10) + ' ppm';
    
    // Update DHT11 combined card (if exists)
    const tempEl = document.getElementById('dht11-temp');
    if (tempEl) tempEl.textContent = (Math.round(data.suhu * 10) / 10) + ' °C';
    
    const humEl = document.getElementById('dht11-humidity');
    if (humEl) humEl.textContent = (Math.round(data.kelembapan * 10) / 10) + ' %';
    
    // Update separate temperature card (if exists)
    const tempValueEl = document.getElementById('temperature-value');
    if (tempValueEl) tempValueEl.textContent = (Math.round(data.suhu * 10) / 10) + ' °C';
    
    // Update separate humidity card (if exists)
    const humValueEl = document.getElementById('humidity-value');
    if (humValueEl) humValueEl.textContent = (Math.round(data.kelembapan * 10) / 10) + ' %';
    
    // Update status value card (if exists)
    const statusValueEl = document.getElementById('status-value');
    if (statusValueEl) {
        // Keep LAYAK/TIDAK LAYAK for Overall Status (don't convert to Normal/Danger)
        const currentStatus = data.status || 'LAYAK';
        statusValueEl.textContent = currentStatus;
        
        // Play voice alert when status changes
        if (currentStatus.includes('TIDAK') && !previousStatus.includes('TIDAK')) {
            console.log('Status changed to TIDAK LAYAK - playing alert');
            playVoiceAlert('User yang terhormat, daging tidak layak konsumsi');
        } else if (currentStatus.includes('LAYAK') && !currentStatus.includes('TIDAK') && previousStatus.includes('TIDAK')) {
            console.log('Status changed to LAYAK - playing alert');
            playVoiceAlert('Daging layak konsumsi');
        }
        previousStatus = currentStatus;
        
        // Update status card styling based on status
        const statusCard = document.getElementById('status-card');
        if (statusCard) {
            console.log('Updating Overall Status card, status:', currentStatus);
            
            // Stop any existing blink animation
            if (blinkInterval) {
                clearInterval(blinkInterval);
                blinkInterval = null;
            }
            
            // Remove existing status classes
            statusCard.classList.remove('normal', 'warning', 'danger');
            statusCard.style.backgroundColor = '';
            statusCard.style.borderLeftColor = '';
            
            // Add appropriate class based on status
            if (currentStatus.includes('TIDAK')) {
                console.log('Setting danger class with blinking animation (TIDAK LAYAK)');
                statusCard.classList.add('danger');
                statusValueEl.className = 'text-3xl font-bold text-red-600';
                
                // Start blinking animation using setInterval
                let isVisible = true;
                blinkInterval = setInterval(function() {
                    if (isVisible) {
                        statusCard.style.backgroundColor = '#fee2e2';
                        statusCard.style.borderLeftColor = '#dc2626';
                        statusValueEl.style.opacity = '0.4';
                    } else {
                        statusCard.style.backgroundColor = '#ffffff';
                        statusCard.style.borderLeftColor = '#ef4444';
                        statusValueEl.style.opacity = '1';
                    }
                    isVisible = !isVisible;
                }, 500); // Kedip setiap 500ms
                
            } else if (currentStatus.includes('PERINGATAN')) {
                console.log('Setting warning class (PERINGATAN)');
                statusCard.classList.add('warning');
                statusValueEl.className = 'text-3xl font-bold text-yellow-600';
                statusValueEl.style.opacity = '1';
            } else {
                console.log('Setting normal class (LAYAK)');
                statusCard.classList.add('normal');
                statusValueEl.className = 'text-3xl font-bold text-green-600';
                statusValueEl.style.opacity = '1';
            }
            
            console.log('Card classes:', statusCard.className);
        }
    }

    // Update sensor statuses
    updateSensorStatus('mq2', data.mq2, thresholds.mq2);
    updateSensorStatus('mq3', data.mq3, thresholds.mq3);
    updateSensorStatus('mq135', data.mq135, thresholds.mq135);
    
    // Update temperature status (separate card)
    updateSensorStatus('temperature', data.suhu, thresholds.temperature);
    
    // Update humidity status (separate card)
    updateSensorStatus('humidity', data.kelembapan, thresholds.humidity);
    

        // Update AI Agent Analysis section
        if (data.ai_analysis) {
            const aiSection = document.getElementById('ai-agent-section');
            const aiStatus = document.getElementById('ai-agent-status');
            const aiExplanation = document.getElementById('ai-agent-explanation');
            const aiThresholds = document.getElementById('ai-agent-thresholds');
            const aiSensorStatus = document.getElementById('ai-agent-sensor-status');

            if (aiSection && aiStatus && aiExplanation && aiThresholds && aiSensorStatus) {
                aiStatus.textContent = `Status Akhir AI: ${data.ai_analysis.final_status || '-'}`;
                aiExplanation.textContent = `Alasan: ${data.ai_analysis.explanation || '-'}`;
                // Adaptive threshold info
                if (data.ai_analysis.adaptive_learning) {
                    let thInfo = 'Threshold adaptif: ';
                    const ths = data.ai_analysis.adaptive_learning;
                    thInfo += Object.keys(ths).map(k => `${k}: ${ths[k].min.toFixed(2)} - ${ths[k].max.toFixed(2)}`).join(', ');
                    aiThresholds.textContent = thInfo;
                } else {
                    aiThresholds.textContent = '';
                }
                // Sensor status
                if (data.ai_analysis.sensor_status) {
                    let sensorInfo = 'Status Sensor: ';
                    const sensors = data.ai_analysis.sensor_status;
                    sensorInfo += Object.keys(sensors).map(k => `${k}: ${sensors[k]}`).join(', ');
                    aiSensorStatus.textContent = sensorInfo;
                } else {
                    aiSensorStatus.textContent = '';
                }
            }
        }
    // Update temperature and humidity status from dht11 card
    if (document.getElementById('dht11-status')) {
        const tempThresholds = { warning: 30, danger: 35 };
        updateSensorStatus('dht11', data.suhu, tempThresholds);
    }

    // Update charts
    if (tempHumChart && gasChart) {
        // Add new data point to temperature & humidity chart
        const timestamp = new Date().toLocaleTimeString();
        
        tempHumChart.data.labels.push(timestamp);
        tempHumChart.data.datasets[0].data.push(data.suhu);
        tempHumChart.data.datasets[1].data.push(data.kelembapan);
        
        // Keep only last 10 points
        if (tempHumChart.data.labels.length > 10) {
            tempHumChart.data.labels.shift();
            tempHumChart.data.datasets[0].data.shift();
            tempHumChart.data.datasets[1].data.shift();
        }
        
        tempHumChart.update();

        // Update gas concentration chart
        gasChart.data.datasets[0].data = [data.mq2, data.mq3, data.mq135];
        gasChart.update();
    }

    // Update last update time
    const lastUpdateEl = document.getElementById('lastUpdate');
    if (lastUpdateEl) {
        lastUpdateEl.textContent = new Date().toLocaleTimeString('id-ID');
    }
    
    // Update grafik bundar kelayakan daging berdasarkan status realtime
    if (meatQualityChart && data.status) {
        let layakValue = 0;
        let tidakLayakValue = 0;
        
        if (data.status.toUpperCase().includes('LAYAK') && !data.status.toUpperCase().includes('TIDAK')) {
            layakValue = 100;
            tidakLayakValue = 0;
        } else {
            layakValue = 0;
            tidakLayakValue = 100;
        }
        
        meatQualityChart.data.datasets[0].data = [layakValue, tidakLayakValue];
        meatQualityChart.update('none'); // Update tanpa animasi untuk realtime
    }
    
    // Update tabel Recent Data dengan data realtime
    const timestamp = new Date().toLocaleTimeString('id-ID');
    const newDataRow = {
        timestamp: timestamp,
        mq2: data.mq2 || 0,
        mq3: data.mq3 || 0,
        mq135: data.mq135 || 0,
        suhu: data.suhu || 0,
        kelembapan: data.kelembapan || 0,
        status: data.status || 'UNKNOWN'
    };
    
    // Tambahkan data baru ke buffer (max 10 rows)
    recentDataBuffer.unshift(newDataRow);
    if (recentDataBuffer.length > 10) {
        recentDataBuffer.pop();
    }
    
    // Update tabel
    updateRecentDataTable();
}

// Fungsi untuk update tabel Recent Data
function updateRecentDataTable() {
    const tableBody = document.getElementById('history-table');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';
    
    recentDataBuffer.forEach(row => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row.timestamp}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(row.mq2 * 10) / 10}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(row.mq3 * 10) / 10}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(row.mq135 * 10) / 10}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(row.suhu * 10) / 10}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(row.kelembapan * 10) / 10}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm ${getStatusColorClass(row.status)}">${row.status}</td>
        `;
        tableBody.appendChild(tr);
    });
}

// Fetch and display historical data in table
function fetchHistoryData() {
    fetch('/api/sensor/history/')
        .then(response => response.json())
        .then(history => {
            const tableBody = document.getElementById('history-table');
            if (!tableBody) return;
            tableBody.innerHTML = '';

            // Hitung rata-rata kelayakan
            let layakCount = 0;
            let totalCount = history.length;
            history.forEach(row => {
                if (row.status && row.status.toUpperCase().includes('LAYAK') && !row.status.toUpperCase().includes('TIDAK')) {
                    layakCount++;
                }
                
                // Handle both 'suhu'/'kelembapan' and 'temperature'/'humidity' keys
                const suhu = row.suhu ?? row.temperature ?? 0;
                const kelembapan = row.kelembapan ?? row.humidity ?? 0;
                const mq2 = row.mq2 ?? 0;
                const mq3 = row.mq3 ?? 0;
                const mq135 = row.mq135 ?? 0;
                
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row.timestamp}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(mq2 * 10) / 10}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(mq3 * 10) / 10}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(mq135 * 10) / 10}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(suhu * 10) / 10}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${Math.round(kelembapan * 10) / 10}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm ${getStatusColorClass(row.status)}">${row.status}</td>
                `;
                tableBody.appendChild(tr);
            });
        })
        .catch(error => console.error('Error fetching history data:', error));
}

// Get status color class for table rows
function getStatusColorClass(status) {
    if (!status) return 'text-gray-600';
    
    const upperStatus = status.toUpperCase();
    if (upperStatus.includes('LAYAK') && !upperStatus.includes('TIDAK')) {
        return 'text-green-600 font-medium';
    } else if (upperStatus.includes('PERINGATAN') || upperStatus.includes('WARNING')) {
        return 'text-yellow-600 font-medium';
    } else if (upperStatus.includes('TIDAK') || upperStatus.includes('DANGER')) {
        return 'text-red-600 font-medium';
    }
    return 'text-gray-600';
}

// Initialize everything when document is ready
document.addEventListener('DOMContentLoaded', function() {
    initializeCharts();
    
    // Initial data fetch
    fetchDashboardData();
    
    // Play initial voice alert after first data load (with delay to allow user interaction)
    setTimeout(function() {
        fetch('/api/status')
            .then(response => response.json())
            .then(data => {
                const currentStatus = data.status || 'LAYAK';
                if (currentStatus.includes('LAYAK') && !currentStatus.includes('TIDAK')) {
                    console.log('Initial load - playing LAYAK alert');
                    playVoiceAlert('Daging layak konsumsi');
                } else if (currentStatus.includes('TIDAK')) {
                    console.log('Initial load - playing TIDAK LAYAK alert');
                    playVoiceAlert('User yang terhormat, daging tidak layak konsumsi');
                }
            })
            .catch(error => {
                console.error('Error fetching initial status:', error);
            });
    }, 1000); // Delay 1 detik untuk memastikan user sudah interact dengan page
    
    // Poll every 1 detik untuk update data recent
    setInterval(fetchDashboardData, 1000); // 1000 ms = 1 detik
});

// Override fetchDashboardData to update with new sensor layout
window.fetchDashboardData = function() {
    fetch('/api/status')
        .then(response => response.json())
        .then(data => {
            console.log('DEBUG: Data received from /api/status:', data);
            console.log('DEBUG: suhu =', data.suhu, 'kelembapan =', data.kelembapan);
            console.log('DEBUG: mq2 =', data.mq2, 'mq3 =', data.mq3, 'mq135 =', data.mq135);
            updateDashboard(data);
        })
        .catch(error => {
            console.error('Error fetching dashboard data:', error);
            console.error('Error details:', error.message);
        });
};