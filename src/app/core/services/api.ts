import { Injectable } from '@angular/core';
import {
  HttpClient,
  HttpInterceptor,
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpErrorResponse,
} from '@angular/common/http';
import { Observable, throwError, from, BehaviorSubject } from 'rxjs';
import { catchError, switchMap, finalize } from 'rxjs/operators';
import { environment } from '../../../environments/environment';
import { ApiErrorResponse } from '../models/api.model';
import { TokenService } from './token';
import { AuthService } from './auth';

@Injectable({ providedIn: 'root' })
export class ApiService {
  constructor(private http: HttpClient, private tokenService: TokenService) {}

  private handleError = (err: any) => {
    const errorResponse: ApiErrorResponse = err.error;
    return throwError(() => errorResponse?.error ?? {
      code: 'UNKNOWN_ERROR',
      message: 'An unexpected error occurred.'
    });
  };

  get<T = any>(url: string, isPublic = false) {
    return this.http
      .get<T>(`${environment.apiUrl}/${url}`, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  post<T = any>(url: string, data: any, isPublic = false) {
    return this.http
      .post<T>(`${environment.apiUrl}/${url}`, data, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  put<T = any>(url: string, data: any, isPublic = false) {
    return this.http
      .put<T>(`${environment.apiUrl}/${url}`, data, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  delete<T = any>(url: string, isPublic = false) {
    return this.http
      .delete<T>(`${environment.apiUrl}/${url}`, this.getHeaders(isPublic))
      .pipe(catchError(this.handleError));
  }

  private getHeaders(isPublic: boolean) {
    if (isPublic) return {};
    const token = this.tokenService.getAccessToken();
    return {
      headers: {
        Authorization: `Bearer ${token ?? ''}`,
      },
    };
  }
}

@Injectable({ providedIn: 'root' })
export class ApiInterceptor implements HttpInterceptor {
  private isRefreshing = false;
  private refreshTokenSubject = new BehaviorSubject<void>(undefined);

  // AuthService di-inject di sini tidak masalah karena
  // ApiInterceptor tidak di-inject oleh AuthService
  constructor(private auth: AuthService) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const authHeader = req.headers.get('Authorization');

    if (!authHeader) {
      return next.handle(req);
    }

    return next.handle(req).pipe(
      catchError((error) => {
        if (error instanceof HttpErrorResponse && error.status === 401) {
          return this.handle401Error(req, next);
        }
        return throwError(() => error);
      })
    );
  }

  private handle401Error(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    if (this.isRefreshing) {
      return this.refreshTokenSubject.pipe(
        switchMap(() => next.handle(req))
      );
    }

    this.isRefreshing = true;

    return from(this.auth.refreshToken()).pipe(
      switchMap((newTokens) => {
        this.refreshTokenSubject.next();
        const clonedReq = req.clone({
          setHeaders: {
            Authorization: `Bearer ${newTokens.accessToken}`,
          },
        });
        return next.handle(clonedReq);
      }),
      catchError((refreshError) => {
        this.auth.logout();
        this.refreshTokenSubject.complete();
        return throwError(() => refreshError);
      }),
      finalize(() => {
        this.isRefreshing = false;
      })
    );
  }
}