from fastapi import FastAPI, HTTPException, Form
from fastapi.responses import HTMLResponse, Response
from fastapi.staticfiles import StaticFiles
import qrcode
import io
import os
from PIL import Image
import uuid

# Configuration (set via the Kubernetes ConfigMap; defaults match previous hardcoded values)
APP_HOST = os.getenv("APP_HOST", "0.0.0.0")
APP_PORT = int(os.getenv("APP_PORT", "8000"))
DEFAULT_QR_SIZE = int(os.getenv("DEFAULT_QR_SIZE", "200"))
DEFAULT_BOX_SIZE = int(os.getenv("DEFAULT_BOX_SIZE", "10"))

app = FastAPI(
    title="QR Code Generator API",
    description="A FastAPI application that generates QR codes from text, URLs, or other data",
    version="1.0.0"
)

# Create static directory for storing generated QR codes
os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
async def root():
    """Serve the main HTML page with QR code generator interface"""
    return INDEX_HTML


INDEX_HTML = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>QR Code Generator</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            
            .container {
                background: white;
                border-radius: 20px;
                box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                padding: 40px;
                max-width: 500px;
                width: 100%;
                text-align: center;
            }
            
            h1 {
                color: #333;
                margin-bottom: 30px;
                font-size: 2.5em;
                font-weight: 300;
            }
            
            .form-group {
                margin-bottom: 25px;
                text-align: left;
            }
            
            label {
                display: block;
                margin-bottom: 8px;
                color: #555;
                font-weight: 500;
            }
            
            input[type="text"], input[type="url"], textarea {
                width: 100%;
                padding: 15px;
                border: 2px solid #e1e5e9;
                border-radius: 10px;
                font-size: 16px;
                transition: border-color 0.3s ease;
            }
            
            input[type="text"]:focus, input[type="url"]:focus, textarea:focus {
                outline: none;
                border-color: #667eea;
            }
            
            textarea {
                resize: vertical;
                min-height: 100px;
            }
            
            .options {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 15px;
                margin-bottom: 25px;
            }
            
            .option-group {
                text-align: left;
            }
            
            input[type="number"] {
                width: 100%;
                padding: 10px;
                border: 2px solid #e1e5e9;
                border-radius: 8px;
                font-size: 14px;
            }
            
            button {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                padding: 15px 30px;
                border-radius: 10px;
                font-size: 16px;
                font-weight: 600;
                cursor: pointer;
                transition: transform 0.2s ease, box-shadow 0.2s ease;
                width: 100%;
            }
            
            button:hover {
                transform: translateY(-2px);
                box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
            }
            
            .result {
                margin-top: 30px;
                padding: 20px;
                background: #f8f9fa;
                border-radius: 10px;
                display: none;
            }
            
            .qr-image {
                max-width: 200px;
                margin: 20px auto;
                display: block;
                border-radius: 10px;
                box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            }
            
            .download-btn {
                background: #28a745;
                margin-top: 15px;
            }
            
            .download-btn:hover {
                box-shadow: 0 10px 20px rgba(40, 167, 69, 0.3);
            }
            
            .error {
                color: #dc3545;
                background: #f8d7da;
                padding: 10px;
                border-radius: 5px;
                margin-top: 10px;
                display: none;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>QR Code Generator</h1>
            
            <form id="qrForm">
                <div class="form-group">
                    <label for="data">Enter text, URL, or data:</label>
                    <textarea id="data" name="data" placeholder="Enter the text, URL, or data you want to encode in the QR code..." required></textarea>
                </div>
                
                <div class="options">
                    <div class="option-group">
                        <label for="size">Size (pixels):</label>
                        <input type="number" id="size" name="size" value="200" min="100" max="500">
                    </div>
                    <div class="option-group">
                        <label for="box_size">Box Size:</label>
                        <input type="number" id="box_size" name="box_size" value="10" min="1" max="20">
                    </div>
                </div>
                
                <button type="submit">Generate QR Code</button>
            </form>
            
            <div class="error" id="error"></div>
            
            <div class="result" id="result">
                <h3>Generated QR Code</h3>
                <img id="qrImage" class="qr-image" alt="Generated QR Code">
                <button class="download-btn" onclick="downloadQR()">Download QR Code</button>
            </div>
        </div>
        
        <script>
            document.getElementById('qrForm').addEventListener('submit', async function(e) {
                e.preventDefault();
                
                const formData = new FormData();
                formData.append('data', document.getElementById('data').value);
                formData.append('size', document.getElementById('size').value);
                formData.append('box_size', document.getElementById('box_size').value);
                
                try {
                    const response = await fetch('/generate-qr', {
                        method: 'POST',
                        body: formData
                    });
                    
                    if (response.ok) {
                        const result = await response.json();
                        document.getElementById('qrImage').src = result.qr_code_url;
                        document.getElementById('result').style.display = 'block';
                        document.getElementById('error').style.display = 'none';
                    } else {
                        const error = await response.json();
                        document.getElementById('error').textContent = error.detail;
                        document.getElementById('error').style.display = 'block';
                        document.getElementById('result').style.display = 'none';
                    }
                } catch (error) {
                    document.getElementById('error').textContent = 'An error occurred while generating the QR code.';
                    document.getElementById('error').style.display = 'block';
                    document.getElementById('result').style.display = 'none';
                }
            });
            
            function downloadQR() {
                const link = document.createElement('a');
                link.href = document.getElementById('qrImage').src;
                link.download = 'qr_code.png';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            }
        </script>
    </body>
    </html>
    """.replace(
    'id="size" name="size" value="200"', f'id="size" name="size" value="{DEFAULT_QR_SIZE}"'
).replace(
    'id="box_size" name="box_size" value="10"', f'id="box_size" name="box_size" value="{DEFAULT_BOX_SIZE}"'
)

@app.post("/generate-qr")
async def generate_qr_code(
    data: str = Form(..., description="Text, URL, or data to encode in QR code"),
    size: int = Form(DEFAULT_QR_SIZE, description="Size of the QR code in pixels"),
    box_size: int = Form(DEFAULT_BOX_SIZE, description="Size of each box in the QR code")
):
    """
    Generate a QR code from the provided data
    
    Args:
        data: Text, URL, or data to encode in the QR code
        size: Size of the QR code in pixels (default: DEFAULT_QR_SIZE, 200)
        box_size: Size of each box in the QR code (default: DEFAULT_BOX_SIZE, 10)
    
    Returns:
        JSON response with the URL to the generated QR code image
    """
    try:
        # Validate inputs
        if not data.strip():
            raise HTTPException(status_code=400, detail="Data cannot be empty")
        
        if size < 100 or size > 500:
            raise HTTPException(status_code=400, detail="Size must be between 100 and 500 pixels")
        
        if box_size < 1 or box_size > 20:
            raise HTTPException(status_code=400, detail="Box size must be between 1 and 20")
        
        # Generate QR code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=box_size,
            border=4,
        )
        qr.add_data(data)
        qr.make(fit=True)
        
        # Create image
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Resize image if needed
        if size != img.size[0]:
            img = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Generate unique filename
        filename = f"qr_code_{uuid.uuid4().hex[:8]}.png"
        filepath = f"static/{filename}"
        
        # Save image
        img.save(filepath, "PNG")
        
        return {
            "message": "QR code generated successfully",
            "qr_code_url": f"/static/{filename}",
            "data": data,
            "size": size,
            "box_size": box_size
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating QR code: {str(e)}")

@app.get("/generate-qr-simple")
async def generate_qr_simple(data: str):
    """
    Simple endpoint to generate QR code with default settings
    
    Args:
        data: Text, URL, or data to encode in the QR code
    
    Returns:
        FileResponse with the generated QR code image
    """
    try:
        if not data.strip():
            raise HTTPException(status_code=400, detail="Data parameter is required")
        
        # Generate QR code with default settings
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=DEFAULT_BOX_SIZE,
            border=4,
        )
        qr.add_data(data)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Save to memory
        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        return Response(
            content=img_byte_arr.getvalue(),
            media_type="image/png",
            headers={"Content-Disposition": 'inline; filename="qr_code.png"'}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating QR code: {str(e)}")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "message": "QR Code Generator API is running"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=APP_HOST, port=APP_PORT) 