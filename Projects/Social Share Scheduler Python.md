
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


##### Inside the Notebook:

Importing `setup` library and initializing the library with `setup.init()`

Endpoint for making linkedin post: `"https://api.linkedin.com/v2/sampletext"` is something like that.
There are some things to remember when posting through api calls, according to the api docs, all post must have a header with Authorization that has a Bearer of social_tokens, and a Payload. 

+ Posts are structured as
  `response = requests.post(endpoint, json=payload, headers=headers)`
  `response.raise_for_status()`
- Adding python helper functions for better error handling.

##### Storing Social Posts in Database through Django:
Lets run `python manage.py startapp posts` this command **creates a new Django app named `posts`** inside your project.

Think of a Django **project** as the whole website, and an **app** as one feature or module inside it, like posts, users, payments, comments, etc.

```markdown

posts/
├── __init__.py
├── admin.py
├── apps.py
├── migrations/
│   └── __init__.py
├── models.py
├── tests.py
└── views.py
```

### What each file is for

- **`models.py`**  
    Define your database models here. For example, a `Post` model with title, body, author.
    
- **`views.py`**  
    Handles request logic. This is where you decide what happens when someone visits a URL.
    
- **`admin.py`**  
    Register your models so they appear in Django’s admin panel.
    
- **`apps.py`**  
    App configuration. Usually you never touch this early on.
    
- **`migrations/`**  
    Stores database migration files when you change models.
    
- **`tests.py`**  
    Write unit tests for this app.

Inside `models.py` we can create our structure like this:
```python
from django.db import models
from django.conf import settings


User = settings.AUTH_USER_MODEL
print(User)


# Create your models here.
class Post(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    content = models.TextField()
    share_on_linkedin = models.BooleanField(default=False)
    shared_at_linkedin = models.DateTimeField(
        auto_now=False, auto_now_add=False, null=True, blank=True
    )

    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

```

Now inside `admin.py`:
import the .models from Posts and initialize the post section on the dashboard 

```python

from .models import Posts

admin.site.register(Posts)
```


this creates a admin dashboard like this. 
![[django dashboard Ui.png]]
#### Using the Django Model save method:
With django `    def save(self, *args, **kwargs):` method we can prevent our program from stop sharing if there is any error
```python

 def save(self, *args, **kwargs):
        # pre-save
        if self.share_on_linkedin and self.can_share_on_linkedin:
            print("sharing on linked")
            self.shared_at_linkedin = timezone.now()
        else:
            print("not sharing on linkedin")
        super().save(*args, **kwargs)
```

### Human readable errors 

With `fstring` I can validate errors in a clear manner. IN this case a function to validate that the post must be atleast more than 5 characters long

```python

def validate_share(value):
    if len(value) < 5:
        raise ValidationError("Content must be longer")

```

### Ensure Linkedin Oauth is connected
By adding a try except block on the `can_share_on_linkedin` function, we check if the user is logged in via the `get_linkedin_user_details` from the `helper functions`

```python
    def can_share_on_linkedin(self):
        try:
            linkedin.get_linkedin_user_details(self.user)
        # except linkedin.UserNotConnectedLinkedin:
        #     raise ValidationError({"user": "you must connect linkedin before sharing "})
        except Exception as e:
            print(e)
            raise ValidationError({"user": f"{e}"})
            # return False

        return not self.share_on_linkedin

```

Of course we can cache the whole thing and we will do it later down the road. 


### Share to linkedin via Database entry
just raising an try exception block using `post_to_linkedin` function.
