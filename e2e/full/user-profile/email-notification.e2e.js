var utils = require('../../utils');

var chai = require('chai');
var chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
var expect = chai.expect;

describe('email notification', function() {
    before(async function(){
        browser.get(browser.params.glob.host + 'user-settings/mail-notifications');

        await utils.common.waitLoader();

        utils.common.takeScreenshot('edit-user-profile', 'mail-notifications');
    });

    it('change project notification to all', async function() {
        let row = $$('.policy-table-row').get(1);

        row.$$('label').get(0).click();

        expect(utils.notifications.success.open()).to.be.eventually.equal(true);
    });

    it('change project notification to no', async function() {
        let row = $$('.policy-table-row').get(1);

        row.$$('label').get(2).click();

        expect(utils.notifications.success.open()).to.be.eventually.equal(true);
    });

    it('change project notification to only', async function() {
        let row = $$('.policy-table-row').get(1);

        row.$$('label').get(1).click();

        expect(utils.notifications.success.open()).to.be.eventually.equal(true);
    });
});
