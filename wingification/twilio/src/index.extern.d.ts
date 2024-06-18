export default interface extern {
  createApp: (baseUrl: string) => Promise<(arg0: ApiRequest) => Promise<ApiResponse>>,
}
/** Allowed HTTP methods for a endpoint. */
export enum HttpMethod {
  GET = 0,
  HEAD = 1,
  POST = 2,
  PUT = 3,
  DELETE = 4,
  CONNECT = 5,
  OPTIONS = 6,
  PATCH = 7,
}
/** Shape of a request to an inflight handler. */
export interface ApiRequest {
  /** The request's body. */
  readonly body?: (string) | undefined;
  /** The request's headers. */
  readonly headers?: (Readonly<Record<string, string>>) | undefined;
  /** The request's HTTP method. */
  readonly method: HttpMethod;
  /** The request's path. */
  readonly path: string;
  /** The request's query string values. */
  readonly query: Readonly<Record<string, string>>;
  /** The path variables. */
  readonly vars: Readonly<Record<string, string>>;
}
/** Shape of a response from a inflight handler. */
export interface ApiResponse {
  /** The response's body. */
  readonly body?: (string) | undefined;
  /** The response's headers. */
  readonly headers?: (Readonly<Record<string, string>>) | undefined;
  /** The response's status code. */
  readonly status?: (number) | undefined;
}