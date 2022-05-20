# Azure Chaos Studio :heart: Azure Load Testing :heart: dapr
This repo contains a simple demo app to show how well Azure Chaos Studio, Azure Load Testing and dapr can work together.

The overall story is like this:
- Use Chaos Studio to check how your application behaves if some strange behaviour comes up in your network
- Use Load Testing to make sure you can test the behaviour in a structured manner and you collect the results
- Use dapr to fix issues in your app without touching code.

## Setup & Demo

1. Create an AKS cluster & install dapr into it.
2. Deploy the yaml files in the /deployment folder. 
```
cd deployment
kubectl apply -f .
```
3. Find out the public IPs of your endpoints
```
kubectl get svc
```
4. Start an Chaos Mesh network chaos using Azure Chaos Studio and the json snippet in chaos/chaos.json.
5. Adjust the IPs in the jmx files in the loadtest folder. 
6. Setup tests in Azure Load Testing using the two jmx files.

## Info
The application design is pretty simple. 
Two frontends are sending a request to the backend app. The backend app is reaching out to an external serivce (an Azure funtion).

One of the frontends has dapr enabled, the other is running without dapr. The only difference is the deployment yaml file.

dapr has resiliency configured to run 100 retries if a request to the backend responds with anything else than an HTTP success status code.
You can see the policy in the resiliency.yaml file.

The backend is configured to return Http status error code 500 if the request to the external http endpoint (an Azure function) is not responding within a configured timeout (500ms). 

Our chaos experiment will introduce a delay by 5000ms when the request goes from backend to the external Azure function. This will result in a timeout of the backendapp. This timeout will result in an error 500 delivered to our frontends.

If the request was triggered by the frontend without dapr enabled, error 500 will be passed on to the client.

If the request was triggered by the frontend with dapr enabled, the retry policy will kick in.





