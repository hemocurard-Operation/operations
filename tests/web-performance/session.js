import {fixture} from './seed.js';
fixture.session={user:{id:'demo',email:'test@example.invalid'}};location.hash='#donors';const {initApp}=await import('../../hemocura-core/bootstrap.js');await initApp();window.sessionReady=true;
