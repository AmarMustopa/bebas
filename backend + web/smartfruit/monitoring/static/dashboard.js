// Fungsi untuk animasi perubahan nilai (jika diperlukan)
// function animateValue(element, start, end, duration) {
//     if (!element) return;
//     let startTimestamp = null;
//     const step = (timestamp) => {
//         if (!startTimestamp) startTimestamp = timestamp;
//         const progress = Math.min((timestamp - startTimestamp) / duration, 1);
//         const value = Math.floor(progress * (end - start) + start);
//         element.textContent = value + (element.id.includes('temp') ? ' °C' : ' %');
//         if (progress < 1) {
//             window.requestAnimationFrame(step);
//         }
//     };
//     window.requestAnimationFrame(step);
// }

// Fungsi untuk memperbarui dashboard dari InfluxDB (realtime)
function fetchDashboardData() {
    // Fetch data realtime dari InfluxDB
    fetch('/api/status')
        .then(response => response.json())
        .then(data => {
            console.log('DEBUG: InfluxDB data received:', data);
            
            // Update MQ2 card
            const mq2ValueEl = document.getElementById('mq2-value');
            if (mq2ValueEl && data.mq2 !== undefined) {
                mq2ValueEl.textContent = (Math.round(data.mq2 * 10) / 10) + ' ppm';
                updateCardStatus('mq2', data.mq2);
            }
            
            // Update MQ3 card
            const mq3ValueEl = document.getElementById('mq3-value');
            if (mq3ValueEl && data.mq3 !== undefined) {
                mq3ValueEl.textContent = (Math.round(data.mq3 * 10) / 10) + ' ppm';
                updateCardStatus('mq3', data.mq3);
            }
            
            // Update MQ135 card
            const mq135ValueEl = document.getElementById('mq135-value');
            if (mq135ValueEl && data.mq135 !== undefined) {
                mq135ValueEl.textContent = (Math.round(data.mq135 * 10) / 10) + ' ppm';
                updateCardStatus('mq135', data.mq135);
            }
            
            // Update Temperature card
            const tempEl = document.getElementById('dht11-temp');
            if (tempEl && data.suhu !== undefined) {
                tempEl.textContent = (Math.round(data.suhu * 10) / 10) + ' °C';
            }
            
            // Update Humidity card
            const humEl = document.getElementById('dht11-humidity');
            if (humEl && data.kelembapan !== undefined) {
                humEl.textContent = (Math.round(data.kelembapan * 10) / 10) + ' %';
            }
            
            // Update last update timestamp
            const lastUpdateEl = document.getElementById('lastUpdate');
            if (lastUpdateEl) {
                lastUpdateEl.textContent = new Date().toLocaleTimeString('id-ID');
            }
        })
        .catch(error => console.error('ERROR: Failed to fetch InfluxDB data:', error));

    // Update tabel riwayat dari database lokal
    fetch('/api/sensor/history')
        .then(response => response.json())
        .then(history => {
            const table = document.getElementById('history-table');
            if (table && Array.isArray(history)) {
                let rows = '';
                history.slice(0, 10).forEach(row => {
                    const timestamp = row.timestamp ? new Date(row.timestamp).toLocaleString('id-ID') : '-';
                    
                    rows += `
                        <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${timestamp}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row.mq2 ? (Math.round(row.mq2 * 10) / 10) : '-'}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row.mq3 ? (Math.round(row.mq3 * 10) / 10) : '-'}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row.mq135 ? (Math.round(row.mq135 * 10) / 10) : '-'}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row.temperature ? (Math.round(row.temperature * 10) / 10) : '-'}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row.humidity ? (Math.round(row.humidity * 10) / 10) : '-'}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm"><span class="status-${(row.status||'').toLowerCase()}">${row.status || '-'}</span></td>
                        </tr>
                    `;
                });
                table.innerHTML = rows;
            }
        })
        .catch(error => console.error('ERROR: Failed to fetch history:', error));
}

// Helper function untuk update card status berdasarkan nilai
function updateCardStatus(sensorType, value) {
    const statusEl = document.getElementById(`${sensorType}-status`);
    const cardEl = document.getElementById(`${sensorType}-card`);
    
    if (!statusEl || !cardEl) return;
    
    // Definisi threshold untuk berbagai sensor
    const thresholds = {
        'mq2': { normal: 300, warning: 500 },
        'mq3': { normal: 1000, warning: 1500 },
        'mq135': { normal: 500, warning: 800 }
    };
    
    const threshold = thresholds[sensorType];
    let status = 'Normal';
    let statusClass = 'normal';
    
    if (threshold) {
        if (value > threshold.warning) {
            status = 'Danger';
            statusClass = 'danger';
        } else if (value > threshold.normal) {
            status = 'Warning';
            statusClass = 'warning';
        }
    }
    
    statusEl.textContent = status;
    statusEl.className = `status-${statusClass} text-sm font-medium`;
    cardEl.className = `status-card ${statusClass}`;
}

// Panggil fetchDashboardData setiap 5 detik untuk update realtime
let updateInterval = setInterval(fetchDashboardData, 5000);

// Event listener untuk tab visibility
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        clearInterval(updateInterval);
    } else {
        fetchDashboardData(); // Update segera ketika tab aktif
        updateInterval = setInterval(fetchDashboardData, 10000);
    }
});

// Load data pertama kali
window.onload = fetchDashboardData;
