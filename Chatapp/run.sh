#!/bin/bash

echo " Starting Django Chat App..."

# Activate virtual environment (if exists)

if [ -d "venv" ]; then
echo " Activating virtual environment..."
source venv/bin/activate
fi

# Install dependencies 

if [ -f "requirements.txt" ]; then
echo "Installing dependencies..."
pip install -r requirements.txt
fi

# Make migrations

echo " Making migrations..."
python3 manage.py makemigrations

# Apply migrations

echo "Applying migrations..."
python3 manage.py migrate

# Collect static files (optional)

if grep -q "STATIC_ROOT" relay/settings.py 2>/dev/null; then
echo " Collecting static files..."
python3 manage.py collectstatic --noinput
fi

# Run server

echo "Running server at http://127.0.0.1:8000/"
python3 manage.py runserver
