# TigerStyle 示例

## 命名单位后缀
```zig
latency_ms_max     // 好的：单位后缀 + 前重后轻
message_size_max
source             // 相同长度便于对齐
target
```

## 结构体定义顺序
```zig
time: Time,
process_id: ProcessID,

const ProcessID = struct { cluster: u128, replica: u8 };
const Tracer = @This();

pub fn init(gpa: std.mem.Allocator, time: Time) !Tracer { ... }
```

## 成对断言
```zig
// 写入前断言
assert(valid);

// 读取后断言
const data = read();
assert(valid(data));
```
