import {fixture} from './seed.js';
import {mountLayout} from '../../hemocura-core/layout.js';
location.hash='#donors';await mountLayout({user:{id:'demo',email:'test@example.invalid'}});window.performanceReady=true;
