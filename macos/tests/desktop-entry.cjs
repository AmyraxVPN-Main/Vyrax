// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
const { app }=require('electron');
app.setPath('userData',process.env.VYRAX_TEST_USER_DATA);
require(process.env.VYRAX_TEST_APP_ROOT+'/linux/main.cjs');
