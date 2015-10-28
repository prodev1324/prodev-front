var utils = require('../../utils');

var chai = require('chai');
var chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
var expect = chai.expect;

describe('user profile - contacts', function() {
    describe('current user', function() {
        before(async function(){
            browser.get(browser.params.glob.host + '/profile');

            await utils.common.waitLoader();

            $$('.tab').get(4).click();

            browser.waitForAngular();

            utils.common.takeScreenshot('user-profile', 'current-user-contacts');
        });

        it('conctacts tab', async function() {
            let contactsCount = await $$('.list-itemtype-user').count();

            expect(contactsCount).to.be.above(0);
        });
    });

    describe('other user', function() {
        before(async function(){
            browser.get(browser.params.glob.host + '/profile/user7');

            await utils.common.waitLoader();

            $$('.tab').get(5).click();

            browser.waitForAngular();

            utils.common.takeScreenshot('user-profile', 'other-user-contacts');
        });

        it('conctacts tab', async function() {
            let contactsCount = await $$('.list-itemtype-user').count();

            await browser.sleep(3000);

            expect(contactsCount).to.be.above(0);
        });
    });
});
