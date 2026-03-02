import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { catchError, throwError } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ApiErrorResponse } from '../models/api-error.model';
import { AuthService } from './auth';

@Injectable({ providedIn: 'root' })
export class ApiService {
  constructor(private http: HttpClient, private auth: AuthService) { }
  private handleError = (err: any) => {
    const errorResponse: ApiErrorResponse = err.error;
    return throwError(() => errorResponse?.error ?? {
      code: 'UNKNOWN_ERROR',
      message: 'An unexpected error occurred.'
    });
  }

  get<T = any>(url: string, isPublic = false) {
    return this.http.get<T>(`${environment.apiUrl}/${url}`, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  post<T = any>(url: string, data: any, isPublic = false) {
    return this.http.post<T>(`${environment.apiUrl}/${url}`, data, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  put<T = any>(url: string, data: any, isPublic = false) {
    return this.http.put<T>(`${environment.apiUrl}/${url}`, data, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  delete<T = any>(url: string, isPublic = false) {
    return this.http.delete<T>(`${environment.apiUrl}/${url}`, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  private getHeaders(isPublic: boolean) {
    if (isPublic) return {};
    return { headers: { Authorization: `Bearer ${this.auth.getToken() ?? ''}` } };
  }
}