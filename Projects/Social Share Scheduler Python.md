
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
Through Django admin which in this case is `http://127.0.0.1:8000/admin/login`, and by creating an app from `developer.linkedin.com` I found by client id and secret key to add linkedin auth on login. 

By default the callback url is not properly defined, thats when this little fix comes in handy, copy the default url that leads to 403 error, then de-structure like below:
+ Remove %, %3f %2f, ? & etc. with real slashes .
	https://www.linkedin.com/oauth/v2/authorization?
	client_id=863zaatf0q5uqg
	redirect_uri=http://127.0.0.1:8000/accounts/oidc/linkedin/login/callback/
	scope=email+openid+profile
	response_type=code
	state=E1nu6MNUJkJ7ow7r


###### Store user access token with Django allauth:
From the allauth documentation site, `Thirdparty/configurations/tokens` I can enable the option to store user access token `SOCIALACCOUNT_STORE_TOKENS = True`


###### Installing Jupyter Notebook dependency with `rav`:
+ By adding `rav` in the `requirements.txt` file with a `rav.yaml`
```yaml

scripts:
  notebook:
    - venv/bin/jupyter notebook

```
then running `pip install -r requirements.txt` to install
Run the notebook with `rav run notebook`