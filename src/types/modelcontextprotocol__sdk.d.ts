declare module '@modelcontextprotocol/sdk' {
  export class Server {
    constructor(config: any, capabilities: any);
    setToolHandler(name: string, handler: (params: any) => Promise<any>): void;
    connect(transport: any): Promise<void>;
    close(): Promise<void>;
  }

  export class StdioServerTransport {
    constructor();
  }
}
