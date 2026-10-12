import 'package:flutter_test/flutter_test.dart';
import 'package:iq_training/link_policy.dart';

void main() {
  LinkAction go(String url, {bool click = true}) =>
      classifyLink(Uri.parse(url), userClick: click);

  test('learner pages load in the app', () {
    expect(go('https://iqtraining.co.uk/user-dashboard/my-courses/'),
        LinkAction.allow);
    expect(go('https://iqtraining.co.uk/login/'), LinkAction.allow);
    expect(go('https://iqtraining.co.uk/courses/level-2-food-hygiene/'),
        LinkAction.allow);
    expect(go('https://iqtraining.co.uk/checkout/'), LinkAction.allow);
    expect(go('https://iqtraining.co.uk/?add-to-cart=123'), LinkAction.allow);
  });

  test('sales pages are blocked', () {
    expect(go('https://iqtraining.co.uk/'), LinkAction.blocked);
    expect(go('https://iqtraining.co.uk'), LinkAction.blocked);
    expect(go('https://iqtraining.co.uk/courses/'), LinkAction.blocked);
    expect(go('https://iqtraining.co.uk/courses'), LinkAction.blocked);
    expect(go('https://iqtraining.co.uk/course-bundles/'), LinkAction.blocked);
    expect(
        go('https://iqtraining.co.uk/product-category/course/food-safety/'),
        LinkAction.blocked);
  });

  test('outside links open externally only when tapped', () {
    expect(go('https://www.facebook.com/x'), LinkAction.external);
    expect(go('https://bank.example/3ds', click: false), LinkAction.allow);
    expect(go('https://www.paypal.com/checkout'), LinkAction.allow);
    expect(go('mailto:info@iqtraining.co.uk'), LinkAction.external);
    expect(go('tel:01234567890'), LinkAction.external);
  });

  test('tabs follow the current page', () {
    Uri u(String p) => Uri.parse('https://iqtraining.co.uk$p');
    expect(tabIndexFor(u('/user-dashboard/my-courses/')), 0);
    expect(tabIndexFor(u('/user-dashboard/')), 1);
    expect(tabIndexFor(u('/user-dashboard/orders/')), 1);
    expect(tabIndexFor(u('/frequently-asked-questions/')), 2);
    expect(tabIndexFor(u('/courses/some-course/')), isNull);
  });
}
