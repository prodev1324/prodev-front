var utils = require('../../../utils');

var adminIntegrationsHelper = require('../../../helpers').adminIntegrations;

var chai = require('chai');
var chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
var expect = chai.expect;

describe('admin - github', function() {
    before(async function(){
        browser.get(browser.params.glob.host + 'project/project-3/admin/third-parties/github');

        await utils.common.waitLoader();

        utils.common.takeScreenshot('integrations', 'github');
    });

    it('save', async function() {
        $('.submit-button').click();

        expect(utils.notifications.success.open()).to.be.eventually.true;
    });
});
