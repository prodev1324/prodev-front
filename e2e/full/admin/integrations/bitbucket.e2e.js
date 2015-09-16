var utils = require('../../../utils');

var adminIntegrationsHelper = require('../../../helpers').adminIntegrations;

var chai = require('chai');
var chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
var expect = chai.expect;

describe('admin - bitbucket', function() {
    before(async function(){
        browser.get('http://localhost:9001/project/project-3/admin/third-parties/bitbucket');

        await utils.common.waitLoader();

        utils.common.takeScreenshot('integrations', 'bitbucket');
    });

    it('save', async function() {
        $('.submit-button').click();

        expect(utils.notifications.success.open()).to.be.eventually.true;
    });
});
