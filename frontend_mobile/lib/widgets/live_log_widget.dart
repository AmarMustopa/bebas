import 'package:flutter/material.dart';

class LiveLogWidget extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const LiveLogWidget({Key? key, required this.logs}) : super(key: key);

  @override
  State<LiveLogWidget> createState() => _LiveLogWidgetState();
}

class _LiveLogWidgetState extends State<LiveLogWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(LiveLogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll ke bottom saat ada data baru
    if (widget.logs.length > oldWidget.logs.length) {
      Future.delayed(const Duration(milliseconds: 100), () {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📡 Live Data Stream (MQTT)',
                  style: TextStyle(
                    color: Colors.cyan.shade300,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${widget.logs.length} entries',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
          // Log entries
          Expanded(
            child:
                widget.logs.isEmpty
                    ? Center(
                      child: Text(
                        'Menunggu data MQTT...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Courier',
                        ),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: widget.logs.length,
                      itemBuilder: (context, index) {
                        final log = widget.logs[index];
                        final suhu = (log['suhu'] ?? 0.0).toStringAsFixed(1);
                        final kelembapan = (log['kelembapan'] ?? 0.0)
                            .toStringAsFixed(1);
                        final mq2 = log['mq2'] ?? 0;
                        final mq3 = log['mq3'] ?? 0;
                        final mq135 = log['mq135'] ?? 0;
                        final status =
                            (log['status'] ?? 'TIDAK_LAYAK').toString();

                        // Perbaiki logic: cek TIDAK dulu sebelum LAYAK
                        final statusUpper = status.toUpperCase();
                        final isLayak =
                            statusUpper.contains('LAYAK') &&
                            !statusUpper.contains('TIDAK');
                        final borderColor = isLayak ? Colors.green : Colors.red;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: borderColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header line
                                Text(
                                  '✅ Data diterima dari MQTT:',
                                  style: TextStyle(
                                    color: Colors.green.shade300,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Data dengan format yang rapi
                                Text(
                                  '   Suhu: ${suhu}°C',
                                  style: TextStyle(
                                    color: Colors.amber.shade200,
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '   Kelembapan: ${kelembapan}%',
                                  style: TextStyle(
                                    color: Colors.amber.shade200,
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '   MQ2: $mq2 ppm',
                                  style: TextStyle(
                                    color: Colors.amber.shade200,
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '   MQ3: $mq3 ppm',
                                  style: TextStyle(
                                    color: Colors.amber.shade200,
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '   MQ135: $mq135 ppm',
                                  style: TextStyle(
                                    color: Colors.amber.shade200,
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Status
                                Text(
                                  '   Status: $status',
                                  style: TextStyle(
                                    color:
                                        isLayak
                                            ? Colors.green.shade300
                                            : Colors.red.shade300,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
