import 'dart:async';
import 'dart:developer' as developer;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart' as vm_service_io;

void main(List<String> arguments) async {
  print('Hello world!');

  // Enable the vm service protocol, even if `--observe` was not passed on the
  // command line.
  developer.ServiceProtocolInfo info =
      await developer.Service.controlWebServer(enable: true);
  //developer.ServiceProtocolInfo info = await developer.Service.getInfo();
  _connectTo(info);

  Timer timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
    // allocate some memory
    List<int> list = List.generate(10000, (index) => index * index);
    int total = list[0] + list[list.length - 1];
  });
}

void _connectTo(developer.ServiceProtocolInfo info) async {
  Uri httpUri = info.serverUri;
  print('http: $httpUri');
  String wsUri = httpUri.replace(scheme: 'ws').toString() + 'ws';
  print('ws: $wsUri');
  print('');

  VmService service = await vm_service_io.vmServiceConnectUri(wsUri.toString());
  service.streamListen(EventStreams.kGC);
  service.onGCEvent.listen((Event event) {
    final HeapSpace newSpace = HeapSpace.parse(event.json['new']);
    final HeapSpace oldSpace = HeapSpace.parse(event.json['old']);

    print(
        'gc: ${_mb(newSpace.used + oldSpace.used)} / ${_mb(newSpace.capacity + oldSpace.capacity)}');
  });

  VM vm = await service.getVM();
  IsolateRef isolateRef = vm.isolates.first;

  Timer timer = Timer.periodic(const Duration(seconds: 4), (timer) async {
    MemoryUsage usage = await service.getMemoryUsage(isolateRef.id);

    print('    ${_mb(usage.heapUsage)} / ${_mb(usage.heapCapacity)}');
  });
}

String _mb(int bytes) {
  final MB = 1024.0 * 1024.0;

  // todo: add commas
  return (bytes / MB).toStringAsFixed(2) + 'MB';
}

class HeapSpace {
  HeapSpace._fromJson(this.json)
      : avgCollectionPeriodMillis = json['avgCollectionPeriodMillis'],
        capacity = json['capacity'],
        collections = json['collections'],
        external = json['external'],
        name = json['name'],
        time = json['time'],
        used = json['used'];

  static HeapSpace parse(Map<String, dynamic> json) =>
      json == null ? null : HeapSpace._fromJson(json);

  final Map<String, dynamic> json;

  final double avgCollectionPeriodMillis;

  final int capacity;

  final int collections;

  final int external;

  final String name;

  final double time;

  final int used;

  @override
  String toString() => '[HeapSpace]';
}
