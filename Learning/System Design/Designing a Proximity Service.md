# A Proximity Service
A proximity service is used to define nearby restaurants, friends, etc. 



## Step 1 :
Establishing design scope. Following questions can be one of the first questions to be asked. 

- *Can a user specify search radius ? When a search spits out nothing does the system auto-expand the search ?*

- *What is the maximum allowed distance that a user can search ?*

- *Is the distance dynamic ?*

- *How the system data is being created ?*



## Functional requirements

+ Return all businesses based on the user's location(pair of longitude and latitude).
+ Businesses can add, update, delete their information.
+ A detailed view of the businesses on the client side.

### Non-functional requirements
+ Low-latency, data privacy, location based services compliancy
+ Data privacy, GDPR compliancy
+ High availability and scalability. System should handle traffic during peak hours, assuming peak hours in densly populated areas.

API Design
We use the RESTful API convention to design a simplified version of the APIs.

GET /v1/search/nearby

This endpoint returns businesses based on certain search criteria. In real-life applications, search results are usually paginated. Pagination [6] is not the focus of this chapter but is worth mentioning during an interview.

Request Parameters:


| Field |Description | Type |
| ----------- | ----------- | ----------- |
| latitude   | latitude given to a location   | decimal   |
| longitude   | longitude given to a location   | decimal   |
| radius   | Optional. Default is 5000 meters (about 3 miles)   | int   |

Field	Description	Type
latitude	Latitude of a given location	decimal
longitude	Longitude of a given location	decimal
radius            	      	int

Response Body

```json

    {
     "total": 10,
     "businesses":[{business object}]
    }

```


APIs for a Business
The APIs related to a business object are shown in the table below

| API  |  Detail | 
| ----------- | ----------- |
| GET/v1/business/{:id}   | Return a detail information about a business   |
| POST/v1/businesses   | Add a business|
| PUT/v1/businesses/{:id}   | Update a business information|
| DELETE/v1/businesses/{:id}   | Delete a business |



## Data Model

Read/Write Ratio:
Read volume will be high because two features are commonly used:
    1. Search for nearby businesses
    2. View the details info of a business

Write volume will be low because adding, removing and editing businesses will be an infrequent operation. 


For a read heavy system, a relational `MYSQL` database should be a good fit.  

Data Schema:
The key database tables are business table and (geo) index table.

Business table:
The business table contains information about a business, where primary key is `business_id`.


Geo index table:
A geo index table is used for efficient processing of spatial operations.



Diagram:
Entry point -> LBS -> READ -> Replicas
Entry point -> Business service -> Write -> Primary -> Replica


Load balancer

The load balancer automatically distributes incoming traffic across multiple services. Normally, a company provides a single DNS entry point and internally routes the API calls to the appropriate services based on the URL paths.


LBS
The LBS service is the core part of the system which finds nearby businesses for a given radius and location. The LBS has the following characteristics:

    + It is a read-heavy service with no write requests.
    + QPS is high, especially during peak hours in dense areas.
    + This service is stateless so it’s easy to scale horizontally.


Business service

Business service mainly deals with two types of requests:

Business owners create, update, or delete businesses. Those requests are mainly write operations, and the QPS is not high.
Customers view detailed information about a business. QPS is high during peak hours.
Database cluster

The database cluster can use the primary-secondary setup. In this setup, the primary database handles all the write operations, and multiple replicas are used for read operations. Data is saved to the primary database first and then replicated to replicas. Due to the replication delay, there might be some discrepancy between data read by the LBS and the data written to the primary database. This inconsistency is usually not an issue because business information doesn’t need to be updated in real-time.

Scalability of business service and LBS

Both the business service and LBS are stateless services, so it’s easy to automatically add more servers to accommodate peak traffic (e.g. mealtime) and remove servers during off-peak hours (e.g. sleep time). If the system operates on the cloud, we can set up different regions and availability zones to further improve availability [9]. We discuss this more in the deep dive.

Algorithms to fetch nearby businesses
In real life, companies might use existing geospatial databases such as Geohash in Redis [10] or Postgres with PostGIS extension [11]. You are not expected to know the internals of those geospatial databases during an interview. It’s better to demonstrate your problem-solving skills and technical knowledge by explaining how the geospatial index works, rather than to simply throw out database names.

The next step is to explore different options for fetching nearby businesses. We will list a few options, go over the thought process, and discuss trade-offs.




