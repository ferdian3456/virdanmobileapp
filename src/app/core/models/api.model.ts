export interface ApiError {
  code: string;
  message: string;
  param?: string;
}

export interface ApiErrorResponse {
  error: ApiError;
}

// Success no data
export interface ApiSuccessResponseNoData {
  status: string;
}