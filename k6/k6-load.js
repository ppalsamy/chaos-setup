import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 30, // 30 concurrent users
  duration: '40m'

};

export default function () {
  const res = http.get('http://backend-podinfo.test.svc.cluster.local:9898/api/info');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 800ms': (r) => r.timings.duration < 800,
  });
  sleep(Math.random() * 0.2); // 0–200ms
}
