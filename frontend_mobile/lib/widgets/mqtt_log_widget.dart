import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MqttLogWidget extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const MqttLogWidget({Key? key, required this.logs}) : super(key: key);

  @override
  State<MqttLogWidget> createState() => _MqttLogWidgetState();
}

class _MqttLogWidgetState extends State<MqttLogWidget> {
  late ScrollController _scrollController;
  int _previousLogCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _previousLogCount = widget.logs.length;
  }

  @override
  void didUpdateWidget(MqttLogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length > _previousLogCount) {
      _previousLogCount = widget.logs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getStatusColor(String status) {
    if (status.contains('LAYAK')) {
      return '🟢'; // Green
    } else if (status.contains('TIDAK')) {
      return '🔴'; // Red
    } else {
      return '🟡'; // Yellow
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade700),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'MQTT Real-time Data Log',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.logs.length} logs',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Logs
          Expanded(
            child: widget.logs.isEmpty
                ? Center(
                    child: Text(
                      'Menunggu data MQTT...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontFamily: 'Courier',
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    separatorBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        height: 1,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    itemCount: widget.logs.length,
                    itemBuilder: (ctx, i) {
                      final log = widget.logs[i];
                      final status = (log['status'] as String? ?? 'UNKNOWN')
                          .replaceAll('_', ' ');
                      final statusIcon = _getStatusColor(status);
                      final timestamp =
                          DateFormat('HH:mm:ss').format(DateTime.now());

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade850,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: status.contains('TIDAK')
                                ? Colors.red.shade700
                                : status.contains('LAYAK')
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timestamp
                            Text(
                              '[$timestamp] 📥 Data diterima dari MQTT:',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontFamily: 'Courier',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Topic
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 16),
                              child: Text(
                                'Topik: annas/esp32/sensor',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontFamily: 'Courier',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Payload
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payload: {',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Courier',
                                      fontSize: 11,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildPayloadField('suhu',
                                            log['suhu'], '°C'),
                                        _buildPayloadField('kelembapan',
                                            log['kelembapan'], '%'),
                                        _buildPayloadField('mq2', log['mq2'],
                                            'ppm'),
                                        _buildPayloadField('mq3', log['mq3'],
                                            'ppm'),
                                        _buildPayloadField('mq135',
                                            log['mq135'], 'ppm'),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '}',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Courier',
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // InfluxDB Success
                            Text(
                              '✅ Data berhasil dikirim ke InfluxDB',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'Courier',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bucket: datamonitoring',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Courier',
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Measurement: sensor_data',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Courier',
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Device: smartfruit01',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Courier',
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Status
                            Row(
                              children: [
                                Text(
                                  statusIcon,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Status: $status',
                                    style: TextStyle(
                                      color: status.contains('TIDAK')
                                          ? Colors.red.shade300
                                          : status.contains('LAYAK')
                                              ? Colors.green.shade300
                                              : Colors.orange.shade300,
                                      fontFamily: 'Courier',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadField(String key, dynamic value, String unit) {
    String displayValue;
    if (value is double) {
      displayValue = value.toStringAsFixed(1);
    } else if (value is int) {
      displayValue = value.toString();
    } else {
      displayValue = value.toString();
    }

    return Text(
      '"$key": $displayValue,$unit',
      style: TextStyle(
        color: Colors.yellowAccent,
        fontFamily: 'Courier',
        fontSize: 11,
      ),
    );
  }
}
