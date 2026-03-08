public class TestReqResCallout {
    public static void execute() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://reqres.in/api/users');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"name": "morpheus", "job": "leader"}');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Status: ' + res.getStatus());
        System.debug('StatusCode: ' + res.getStatusCode());
        System.debug('Body: ' + res.getBody());
    }
}
