需要实现的能力：AE 网络引擎的逻辑链路上下文

能力：
1）在 UDP/TCP 连接成功后
2）创建 网络引擎的上下文
3）网络引擎在收到 IO 口时，需要根据自身的情况进行链路上下文的创建
4）



文件：
AEIOProtocol : 定义 IO 口的能力 发送 、 接收回调注册与删除

AEDataStream : 包装 AESession，接收与返回给上层业务的 数据 TX或RX。AEDataStream 需要通过

根据 AEIOProtocol mtu 的大小进行 AEDataStream 数据包的切包进行发送，AEDataStream 数据需要 AENetSecruity 进行加密之后，再进行切包 AEIOModel，AEIOModel 包含 MTU数据包的包头，包头包含：magic|identifier|index|length|data 长度：2字节｜2字节｜1字节｜2字节｜数据，这套数据包头无法处理总包拼接成功，想一套更合更的。

AESession 接收数据包之后通过 数据包头前面的 index 进行拼接，然后通过 AENetSecruity 解密后返回给上层业务处理。

