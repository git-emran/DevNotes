
### Creating the Project structure


###### Lets start with python virtual environment. 
 - We create a venv or virtual environment using `python3 -m venv venv`. This creates a virtual environment.
 - Activate by running `source venv/bin/activate`
 - Starting a Django environment with `django-admin startproject #projectname`
 - Check the server with `python manage.py runserver`
 - Running `python manage.py migrate` and `python manage.py createsuperuser` to create a admin, which can be accessed through  http://127.0.0.1:8000/admin
###### requirement.txt: 
Following the best practices, having a rquirement.txt file is a must. I started with `Django` on the file, then running `pip install -r requirement.txt`

###### Django allauth: 
Using allauth for authentication.

following the quickstart guide and , copying only the necessary allauth codes, finally run `python manage.py migrate` that handles the auth for the user. 

###### LinkedIn with Django AllAuth & OpenID Connect

 