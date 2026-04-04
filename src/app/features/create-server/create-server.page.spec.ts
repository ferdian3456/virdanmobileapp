import { ComponentFixture, TestBed } from '@angular/core/testing';
import { CreateServerPage } from './create-server.page';

describe('CreateServerPage', () => {
  let component: CreateServerPage;
  let fixture: ComponentFixture<CreateServerPage>;

  beforeEach(() => {
    fixture = TestBed.createComponent(CreateServerPage);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
