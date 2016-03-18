var utils = require('../utils');
var teamHelper = require('../helpers').team;

var chai = require('chai');
var chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
var expect = chai.expect;

describe('leaving project', function(){
    before(async function(){
        browser.get(browser.params.glob.host + 'project/project-4/team');
        await utils.common.waitLoader();
    });

    it('leave project', async function(){
        teamHelper.team().leave();
        await utils.lightbox.confirm.ok();
        await utils.common.takeScreenshot("team", "after-leaving");
    });
});

describe('leaving project owner', function(){
    before(async function(){
        await utils.common.createProject();
        await utils.nav
            .init()
            .team()
            .go();
    });

    it('leave project', async function(){
        teamHelper.team().leave();

        let isLeaveProjectWarningOpen = await teamHelper.isLeaveProjectWarningOpen();

        await utils.common.takeScreenshot("team", "leave-project-warning");

        expect(isLeaveProjectWarningOpen).to.be.equal(true);

        let lb = teamHelper.leavingProjectWarningLb();

        await utils.lightbox.exit(lb);
        await utils.lightbox.close(lb);
    });
});

describe('team', function() {
    before(async function(){
        browser.get(browser.params.glob.host + 'project/project-5/team');
        await utils.common.waitLoader();
    });

    it('screenshot', async function() {
        await utils.common.takeScreenshot("team", "team");
    });

    it('team filled', async function() {
        let total = await teamHelper.team().count();
        expect(total).to.be.equal(10);
    });

    it('search username', async function() {
        let firstMemberName = await teamHelper.team().firstMember().getText();
        teamHelper.filters().searchText(firstMemberName);
        let total = await teamHelper.team().count();
        expect(total).to.be.equal(1);
        await utils.common.takeScreenshot("team", "searching-by-name");
    });

    it('filter role', async function(){
        teamHelper.filters().clearText();
        let total = await teamHelper.team().count();
        let firstRole = await teamHelper.team().firstRole();
        let roleName = await firstRole.getText();
        teamHelper.filters().filterByRole(roleName);
        let newTotal = await teamHelper.team().count();
        expect(newTotal).to.be.below(total);
        expect(newTotal).to.be.least(1);
        await utils.common.takeScreenshot("team", "filtering-by-role");
    });
});
