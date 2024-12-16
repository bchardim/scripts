COURSE_OR_LESSON=$1
su - student -c "source /home/student/.venv/labs/bin/activate && pip install --upgrade --extra-index-url https://pypi.apps.tools-na.prod.nextcle.com/repository/labs/simple rht-labs-${COURSE_OR_LESSON} && deactivate && lab select ${COURSE_OR_LESSON}"
