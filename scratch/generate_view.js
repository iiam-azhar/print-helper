const fs = require('fs');

const images = [
  {
    name: 'Android Adaptive Foreground (drawable-xxxhdpi)',
    path: 'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
    background: '#000000',
    mask: 'circle'
  },
  {
    name: 'Android Legacy/Fallback (mipmap-xxxhdpi)',
    path: 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    background: '#222',
    mask: 'none'
  },
  {
    name: 'iOS App Icon (1024x1024)',
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    background: '#222',
    mask: 'none'
  }
];

let html = `<!DOCTYPE html>
<html>
<head>
  <style>
    body {
      background-color: #1a1a1a;
      color: #fff;
      font-family: sans-serif;
      padding: 30px;
    }
    .container {
      display: flex;
      flex-wrap: wrap;
      gap: 30px;
    }
    .card {
      background: #2b2b2b;
      border: 1px solid #3d3d3d;
      padding: 15px;
      border-radius: 12px;
      text-align: center;
      width: 280px;
    }
    .img-container {
      position: relative;
      width: 200px;
      height: 200px;
      margin: 15px auto;
      background: #444;
      border-radius: 8px;
      overflow: hidden;
    }
    .preview-img {
      max-width: 100%;
      max-height: 100%;
      width: 200px;
      height: 200px;
      object-fit: contain;
    }
    /* Adaptive Icon Simulation */
    .adaptive-container {
      position: relative;
      width: 150px;
      height: 150px;
      margin: 15px auto;
      border-radius: 50%; /* Circle Mask simulation */
      overflow: hidden;
      background: #000000; /* adaptive_icon_background */
      box-shadow: 0 4px 10px rgba(0,0,0,0.5);
    }
    .adaptive-foreground {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      object-fit: contain;
      /* Simulate the 16% inset applied in XML */
      transform: scale(0.68); 
    }
  </style>
</head>
<body>
  <h1>Generated App Icons Verification</h1>
  <p>Verifying the look of the generated launcher icons after the update.</p>
  
  <div class="container">
`;

images.forEach(img => {
  if (fs.existsSync(img.path)) {
    html += `    <div class="card">
      <h3>${img.name}</h3>
      <div class="img-container">
        <img class="preview-img" src="${img.path}" />
      </div>
    </div>\n`;
  } else {
    html += `    <div class="card">
      <h3>${img.name}</h3>
      <div style="color: #ff6b6b; padding: 50px 0;">FILE NOT FOUND:<br>${img.path}</div>
    </div>\n`;
  }
});

// Add Simulated Adaptive Icon Card
const fgPath = 'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png';
if (fs.existsSync(fgPath)) {
  html += `
    <div class="card" style="border: 2px solid #ffca28;">
      <h3 style="color: #ffca28;">Simulated Android Adaptive Circle Icon</h3>
      <p style="font-size: 11px; opacity: 0.8;">Background: #000000, Foreground: phh_foreground.png scaled to fit Android safe zone inside a circular mask.</p>
      <div class="adaptive-container">
        <img class="adaptive-foreground" src="${fgPath}" />
      </div>
      <p style="font-size: 12px; color: #a5d6a7; font-weight: bold;">Matches Chrome Circular Style!</p>
    </div>
  `;
}

html += `  </div>
</body>
</html>`;

fs.writeFileSync('view_generated.html', html);
console.log('Generated view_generated.html');
