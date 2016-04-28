var utils = require('../utils');

var helper = module.exports;

helper.getSection = function(item) {
    let section = $$('.admin-attributes-section').get(item);

    return {
        el: section,
        openNew: function() {
            section.$('.show-add-new').click();

            return section.$$('form').last();
        },
        rows: function() {
            return section.$$('.sortable > div');
        },
        delete: function(row) {
            let deleteButton = row.$$('.delete-value').first();

            return browser.actions()
                .mouseMove(deleteButton)
                .click()
                .perform();
        },
        edit: async function(row) {
            let editButton = row.$('.edit-value');

            return browser.actions()
                .mouseMove(editButton)
                .click()
                .perform();
        }
    };
};

helper.getStatusNames = function(section) {
    return section.$$('.status-name span').getText();
};

helper.getForm = function(form) {
    return {
        save: function() {
            let saveButton = form.$('.e2e-save');

            browser.actions()
                .mouseMove(saveButton)
                .click()
                .perform();

            // debounce
            return browser.sleep(2000);
        },
        errors: function() {
            return form.$$('.checksley-error-list li');
        }
    };
};

helper.getStatusForm = function(form) {
    let obj = Object.create(helper.getForm(form));

    obj.form = form;

    obj.status = function() {
        return this.form.$('.status-name input');
    };

    return obj;
};

helper.getPointsNames = function(section) {
    return section.$$('.project-values-body .project-values-name span').getText();
};

helper.getPointsForm = function(form) {
    let obj = Object.create(helper.getForm(form));

    obj.name = function() {
        return form.$('.project-values-name input');
    };

    obj.value = function() {
        return form.$('.project-values-value input');
    };

    return obj;
};

helper.getGenericForm = function(form) {
    let obj = Object.create(helper.getForm(form));

    obj.name = function() {
        return form.$('.status-name input');
    };

    return obj;
};

helper.getGenericNames = function(section) {
    return section.$$('.status-name span').getText();
};

helper.waitLoad = function() {
    return browser.wait(function() {
        return $('.admin-attributes').isPresent();
    }, 5000);
};
