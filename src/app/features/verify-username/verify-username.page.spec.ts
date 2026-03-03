import { ComponentFixture, TestBed } from '@angular/core/testing';
import { VerifyUsernamePage } from './verify-username.page';

describe('VerifyUsernamePage', () => {
  let component: VerifyUsernamePage;
  let fixture: ComponentFixture<VerifyUsernamePage>;

  beforeEach(() => {
    fixture = TestBed.createComponent(VerifyUsernamePage);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
